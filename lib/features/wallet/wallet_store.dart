import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';

/// Ví NP và trạng thái các gói trả phí.
///
/// NP là đơn vị trong app: dùng để boost đơn ứng tuyển, mở Insight, đăng ký
/// Job Match Alert. Tab Hồ sơ vẫn hiện số dư từ /profiles/me, nhưng con số
/// đó không đi kèm lịch sử nào nên bấm vào chẳng có gì.
class WalletStore extends ChangeNotifier {
  WalletStore._();
  static final instance = WalletStore._();

  final _api = ApiClient();

  int balance = 0;

  /// NP đang bị giữ cho một giao dịch chưa xong. Hiện riêng chứ không trừ vào
  /// số dư: trừ ngầm thì người dùng thấy số tụt mà không hiểu vì sao.
  int locked = 0;

  bool isPremium = false;
  bool hasMatchAlert = false;
  DateTime? premiumUntil;
  DateTime? matchAlertUntil;

  int premiumPriceNp = 0;
  List<WalletTx> transactions = const [];

  /// Giá từng dịch vụ, lấy từ /premium/config.
  Map<String, int> prices = const {};

  bool loaded = false;

  Future<void> hydrate() async {
    try {
      final results = await Future.wait([
        _try('/wallet'),
        _try('/premium/config'),
      ]);

      final w = results[0];
      if (w is Map) {
        balance = _int(w['npBalance']);
        locked = _int(w['lockedNpBalance']);
        isPremium = w['isPremium'] == true;
        hasMatchAlert = w['hasJobMatchAlert'] == true;
        premiumUntil = _date(w['premiumUntil']);
        matchAlertUntil = _date(w['jobMatchAlertUntil']);
        premiumPriceNp = _int(w['premiumPriceNp']);
        transactions = (w['recentTransactions'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(WalletTx.fromJson)
                .toList() ??
            const [];
      }

      final c = results[1];
      if (c is Map) {
        prices = {
          for (final e in c.entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt(),
        };
      }

      loaded = true;
      notifyListeners();
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

  /// Mua Job Match Alert. Trả null khi xong, chuỗi lỗi khi hỏng.
  Future<String?> subscribeMatchAlert() =>
      _spend('/premium/match-alert/subscribe');

  /// Mua Premium Pass.
  Future<String?> buyPremium() => _spend('/wallet/subscribe');

  /// Đẩy một đơn ứng tuyển lên đầu danh sách của nhà tuyển dụng.
  Future<String?> boost(String applicationId, {required bool isQuest}) =>
      _spend('/premium/boost?applicationId=$applicationId'
          '&applicationType=${isQuest ? 'QUEST' : 'JOB'}');

  Future<String?> _spend(String path) async {
    try {
      await _api.post(path);
      // Nạp lại ngay: số dư vừa đổi, và nếu không nạp thì màn ví hiện số cũ
      // đúng lúc người dùng đang nhìn xem tiền đã trừ chưa.
      await hydrate();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void clear() {
    balance = locked = premiumPriceNp = 0;
    isPremium = hasMatchAlert = loaded = false;
    premiumUntil = matchAlertUntil = null;
    transactions = const [];
    prices = const {};
    notifyListeners();
  }

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse('$v')?.toLocal();
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
