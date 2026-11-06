import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/api_client.dart';
import 'wallet_store.dart';

/// Nạp NP qua Google Play Billing — chỉ dùng trên Android.
///
/// Google Play bắt mọi giao dịch mua hàng số trong app Android đi qua hệ
/// thống thanh toán của họ, nên bản Android không dùng PayOS.
///
/// App KHÔNG tự cộng NP: mua xong thì gửi purchaseToken lên backend, backend
/// hỏi lại Google rồi mới cộng và consume. App chỉ báo kết quả.
///
/// Lắng nghe purchaseStream suốt vòng đời app chứ không chỉ khi mở màn nạp:
/// giao dịch có thể xong lúc màn đã đóng (trả sau, mất mạng, app bị tắt), và
/// khi đó nó phải được gửi lên backend ở lần mở app sau.
class PlayBilling {
  PlayBilling._();
  static final instance = PlayBilling._();

  /// ProductId trùng từng ký tự với sản phẩm trong Play Console và với bảng
  /// giá ở backend (GooglePlayService.PRODUCTS).
  static const productNp = {
    'np_39k': 39000,
    'np_69k': 69000,
    'np_99k': 99000,
    'np_199k': 199000,
  };

  static bool get supported => !kIsWeb && Platform.isAndroid;

  final _iap = InAppPurchase.instance;
  final _api = ApiClient();
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Kết quả các giao dịch, cho màn nạp đang mở hiển thị.
  final _events = StreamController<PlayPurchaseEvent>.broadcast();
  Stream<PlayPurchaseEvent> get events => _events.stream;

  /// Token đang gửi lên backend — chặn gửi trùng khi stream phát lại.
  final _inFlight = <String>{};

  /// Bắt đầu lắng nghe. Gọi nhiều lần không sao.
  ///
  /// Gọi khi người dùng đã đăng nhập: gửi token lên backend cần phiên đăng
  /// nhập, và NP phải vào đúng ví của người đã mua.
  Future<void> start() async {
    if (!supported || _sub != null) return;
    if (!await _iap.isAvailable()) return;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      debugPrint('[PlayBilling] purchaseStream lỗi: $e');
    });
    // Trên Android, restorePurchases phát lại các giao dịch CHƯA consume —
    // tức đã trả tiền nhưng backend chưa cộng (mất mạng, app bị tắt...).
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[PlayBilling] restorePurchases lỗi: $e');
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Danh sách gói NP lấy từ Google Play, xếp theo số NP tăng dần.
  ///
  /// Rỗng khi chưa tạo sản phẩm trong Play Console, hoặc máy không có Google
  /// Play — màn nạp hiện thông báo thay vì lỗi.
  Future<List<ProductDetails>> loadProducts() async {
    if (!supported || !await _iap.isAvailable()) return const [];
    final res = await _iap.queryProductDetails(productNp.keys.toSet());
    final list = res.productDetails.toList()
      ..sort((a, b) => (productNp[a.id] ?? 0).compareTo(productNp[b.id] ?? 0));
    return list;
  }

  /// Mở hộp thoại thanh toán của Google Play. Kết quả về qua [events].
  Future<bool> buy(ProductDetails product) async {
    await start();
    final tag = WalletStore.instance.playAccountTag;
    return _iap.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product,
        // Thành obfuscatedAccountId ở phía Google; backend so khớp để chắc
        // giao dịch này đúng là của người đang đăng nhập.
        applicationUserName: tag.isEmpty ? null : tag,
      ),
      // Backend consume sau khi đã cộng NP. Để thư viện tự consume thì app bị
      // tắt đúng lúc là giao dịch biến mất trong khi NP chưa vào ví.
      autoConsume: false,
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _events.add(PlayPurchaseEvent.pending(p.productID));
        case PurchaseStatus.canceled:
          _events.add(PlayPurchaseEvent.canceled(p.productID));
          await _complete(p);
        case PurchaseStatus.error:
          _events.add(PlayPurchaseEvent.failed(
              p.productID, p.error?.message ?? 'Thanh toán không thành công.'));
          await _complete(p);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(p);
      }
    }
  }

  Future<void> _verify(PurchaseDetails p) async {
    final token = p.verificationData.serverVerificationData;
    if (token.isEmpty || !_inFlight.add(token)) return;
    try {
      final res = await _api.post('/payments/google-play/verify', body: {
        'productId': p.productID,
        'purchaseToken': token,
      });
      final map = Map<String, dynamic>.from(res as Map);
      if (map['pending'] == true) {
        _events.add(PlayPurchaseEvent.pending(p.productID));
        return;
      }
      await _complete(p);
      await WalletStore.instance.refreshAfterTopUp();
      final amount = (map['amountNp'] as num?)?.toInt() ?? productNp[p.productID] ?? 0;
      _events.add(PlayPurchaseEvent.success(p.productID, amount,
          newlyCredited: map['credited'] == true));
    } on ApiException catch (e) {
      // KHÔNG complete: giao dịch còn treo để lần mở app sau gửi lại. Nếu
      // backend tạm hỏng mà mình consume ở đây thì người dùng mất tiền.
      _events.add(PlayPurchaseEvent.failed(p.productID,
          'Đã thanh toán nhưng chưa cộng được NP: ${e.message} '
          'NP sẽ được cộng tự động khi bạn mở lại ứng dụng.'));
    } catch (e) {
      _events.add(PlayPurchaseEvent.failed(p.productID,
          'Đã thanh toán nhưng chưa cộng được NP. '
          'NP sẽ được cộng tự động khi bạn mở lại ứng dụng.'));
    } finally {
      _inFlight.remove(token);
    }
  }

  Future<void> _complete(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(p);
    } catch (e) {
      // Backend đã consume thì acknowledge ở đây báo lỗi — vô hại.
      debugPrint('[PlayBilling] completePurchase: $e');
    }
  }
}

enum PlayPurchaseKind { pending, success, canceled, failed }

class PlayPurchaseEvent {
  const PlayPurchaseEvent._(this.kind, this.productId,
      {this.amountNp = 0, this.message, this.newlyCredited = false});

  factory PlayPurchaseEvent.pending(String id) =>
      PlayPurchaseEvent._(PlayPurchaseKind.pending, id);
  factory PlayPurchaseEvent.canceled(String id) =>
      PlayPurchaseEvent._(PlayPurchaseKind.canceled, id);
  factory PlayPurchaseEvent.failed(String id, String message) =>
      PlayPurchaseEvent._(PlayPurchaseKind.failed, id, message: message);
  factory PlayPurchaseEvent.success(String id, int amountNp,
          {required bool newlyCredited}) =>
      PlayPurchaseEvent._(PlayPurchaseKind.success, id,
          amountNp: amountNp, newlyCredited: newlyCredited);

  final PlayPurchaseKind kind;
  final String productId;
  final int amountNp;
  final String? message;
  final bool newlyCredited;
}
