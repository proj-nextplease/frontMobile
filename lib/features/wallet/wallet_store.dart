import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import 'play_billing.dart';

/// Ví NP.
///
/// Theo mô hình điểm hiện tại (giống tab Cửa hàng trên web) NP chỉ dùng cho
/// HAI việc: phí nhận việc có thù lao và phí cập nhật website portfolio.
/// Premium, Job Match Alert, đẩy đơn, Insight, duyệt nhanh đã bỏ.
class WalletStore extends ChangeNotifier {
  WalletStore._();
  static final instance = WalletStore._();

  final _api = ApiClient();

  int balance = 0;

  /// NP đang bị giữ cho một giao dịch chưa xong. Hiện riêng chứ không trừ vào
  /// số dư: trừ ngầm thì người dùng thấy số tụt mà không hiểu vì sao.
  int locked = 0;

  /// Phí xác nhận nhận một việc CÓ thù lao. Mặc định 19.000 giống web khi
  /// /wallet chưa trả khoá này.
  int jobAcceptanceFeeNp = 19000;

  /// Phí cập nhật website portfolio từ lần xuất thứ hai (lần đầu miễn phí).
  int portfolioExportFeeNp = 1000;

  /// Các gói nạp gợi ý — CÙNG bộ số với web (39K/69K/99K/199K) và lấy từ
  /// /wallet để admin đổi một chỗ là cả hai bên đổi theo.
  List<int> topupSuggestions = const [39000, 69000, 99000, 199000];
  int defaultTopupNp = 39000;

  /// Số tiền nạp tối thiểu, lấy từ máy chủ (khoá min_topup_vnd, admin sửa
  /// được). Ghi cứng 10.000 ở đây thì đổi cấu hình xong app vẫn chặn theo
  /// mức cũ.
  int minTopupVnd = 10000;

  /// Mã ẩn danh của tài khoản, gắn vào giao dịch Google Play để backend kiểm
  /// giao dịch đúng là của người này.
  String playAccountTag = '';
  List<WalletTx> transactions = const [];

  bool loaded = false;

  Future<void> hydrate() async {
    try {
      final w = await _try('/wallet');
      if (w is Map) {
        balance = _int(w['npBalance']);
        locked = _int(w['lockedNpBalance']);
        final fee = _int(w['paidJobAcceptanceFeeNp']);
        if (fee > 0) jobAcceptanceFeeNp = fee;
        final exportFee = _int(w['portfolioExportFeeNp']);
        if (exportFee > 0) portfolioExportFeeNp = exportFee;
        final defPkg = _int(w['defaultTopupPackageNp']);
        if (defPkg > 0) defaultTopupNp = defPkg;
        final sug = (w['topupSuggestions'] as List?)
            ?.whereType<num>()
            .map((e) => e.toInt())
            .toList();
        if (sug != null && sug.isNotEmpty) topupSuggestions = sug;
        final minTopup = _int(w['minTopupVnd']);
        if (minTopup > 0) minTopupVnd = minTopup;
        playAccountTag = '${w['playAccountTag'] ?? ''}';
        transactions = (w['recentTransactions'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(WalletTx.fromJson)
                .toList() ??
            const [];
      }

      loaded = true;
      notifyListeners();

      // Đã đăng nhập: bắt đầu nghe giao dịch Google Play, và gửi lại những
      // giao dịch đã trả tiền mà lần trước chưa kịp cộng NP.
      unawaited(PlayBilling.instance.start());
    } on ApiException {
      // Khách hoặc endpoint hỏng: màn ví hiện trạng thái rỗng, không phải lỗi
      // đỏ giữa màn hình.
    }
  }

  Future<Object?> _try(String path) async {
    try {
      return await _api.get(path);
    } on ApiException {
      return null;
    }
  }

  /// Tạo một yêu cầu nạp qua PayOS.
  ///
  /// CHƯA cộng NP. Trả về thông tin chuyển khoản để màn thanh toán hiện lên;
  /// tiền chỉ vào ví khi PayOS gọi webhook về backend. App không bao giờ tự
  /// cộng tiền dựa trên bất cứ thứ gì nó tự quan sát được.
  ///
  /// Ném [ApiException] khi hỏng, để màn gọi tự quyết hiển thị ra sao.
  Future<TopUpRequest> createTopUp(int amountVnd) async {
    if (amountVnd < minTopupVnd) {
      throw ApiException('Số tiền nạp tối thiểu là ${_money(minTopupVnd)} VND.');
    }
    if (amountVnd > 10000000) {
      throw ApiException('Số tiền nạp tối đa là ${_money(10000000)} VND.');
    }
    final res = await _api.post('/payments/payos/create',
        body: {'amountVnd': amountVnd});
    return TopUpRequest.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Hỏi trạng thái một yêu cầu nạp: PENDING / PAID / CANCELLED / EXPIRED...
  ///
  /// Đây là nguồn sự thật duy nhất cho câu hỏi "tiền vào chưa". Việc chuyển
  /// khoản diễn ra trong app ngân hàng — app này không hề hay biết, nên cách
  /// duy nhất để biết là hỏi máy chủ.
  Future<String> topUpStatus(int orderCode) async {
    final res = await _api.get('/payments/payos/status',
        query: {'orderCode': '$orderCode'});
    final map = Map<String, dynamic>.from(res as Map);
    return (map['status'] ?? 'PENDING').toString();
  }

  /// Huỷ một yêu cầu nạp đang chờ.
  ///
  /// Backend chỉ huỷ khi đơn còn PENDING, nên gọi nhầm lúc tiền vừa vào cũng
  /// không làm mất khoản đã trả.
  Future<void> cancelTopUp(int orderCode) async {
    await _api.post('/payments/payos/cancel', body: {'orderCode': orderCode});
  }

  /// Nạp lại số dư sau khi thanh toán xong.
  Future<void> refreshAfterTopUp() => hydrate();

  void clear() {
    unawaited(PlayBilling.instance.stop());
    playAccountTag = '';
    balance = locked = 0;
    loaded = false;
    transactions = const [];
    notifyListeners();
  }

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;

  /// 50000 → "50.000". Dấu chấm phân nhóm, đúng quy ước tiếng Việt và khớp
  /// với cách các giá khác trong app đang hiện.
  static String _money(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String money(int v) => _money(v);
  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse('$v')?.toLocal();
}

/// Số liệu cạnh tranh của một tin tuyển dụng.
class TopUpRequest {
  const TopUpRequest({
    required this.orderCode,
    required this.amountVnd,
    required this.accountNumber,
    required this.accountName,
    required this.bin,
    required this.description,
    required this.qrCode,
    required this.checkoutUrl,
  });

  /// Mã đơn dạng số. PayOS dùng chính nó để báo về, và app dùng nó để hỏi
  /// trạng thái.
  final int orderCode;

  final int amountVnd;
  final String accountNumber;
  final String accountName;
  final String bin;

  /// Nội dung chuyển khoản. Đổi nội dung là khoản tiền mất đường về đúng đơn.
  final String description;

  /// Chuỗi VietQR thô — app tự vẽ thành mã, không phải ảnh tải về.
  final String qrCode;

  /// Trang thanh toán của PayOS, giữ làm đường lùi.
  final String checkoutUrl;

  factory TopUpRequest.fromJson(Map<String, dynamic> m) => TopUpRequest(
        orderCode: WalletStore._int(m['orderCode']),
        amountVnd: WalletStore._int(m['amountVnd']),
        accountNumber: '${m['accountNumber'] ?? ''}',
        accountName: '${m['accountName'] ?? ''}',
        bin: '${m['bin'] ?? ''}',
        description: '${m['description'] ?? ''}',
        qrCode: '${m['qrCode'] ?? ''}',
        checkoutUrl: '${m['checkoutUrl'] ?? ''}',
      );
}

class WalletTx {
  const WalletTx({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    this.reason,
    this.createdAt,
  });

  final String id;

  /// Âm là chi, dương là thu. Backend lưu dấu sẵn nên không cần suy từ `type`.
  final int amount;

  final int balanceAfter;
  final String type;
  final String? reason;
  final DateTime? createdAt;

  factory WalletTx.fromJson(Map<String, dynamic> m) => WalletTx(
        id: '${m['id']}',
        amount: WalletStore._int(m['amount_np']),
        balanceAfter: WalletStore._int(m['balance_after_np']),
        type: '${m['transaction_type'] ?? ''}',
        reason: () {
          final s = m['reason']?.toString().trim();
          return (s == null || s.isEmpty) ? null : s;
        }(),
        createdAt: WalletStore._date(m['created_at']),
      );
}
