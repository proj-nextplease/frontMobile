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

  /// Số tiền nạp tối thiểu, lấy từ máy chủ (khoá min_topup_vnd, admin sửa
  /// được). Ghi cứng 10.000 ở đây thì đổi cấu hình xong app vẫn chặn theo
  /// mức cũ.
  int minTopupVnd = 10000;
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
        final minTopup = _int(w['minTopupVnd']);
        if (minTopup > 0) minTopupVnd = minTopup;
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

  /// Mua Premium Pass.
  Future<String?> buyPremium() => _spend('/wallet/subscribe');

  /// Đẩy một đơn ứng tuyển lên đầu danh sách của nhà tuyển dụng.
  Future<String?> boost(String applicationId, {required bool isQuest}) =>
      _spend('/premium/boost?applicationId=$applicationId'
          '&applicationType=${isQuest ? 'QUEST' : 'JOB'}');

  /// Mở Insight cho một tin đã ứng tuyển. Trừ NP.
  ///
  /// `targetId` là id của TIN (job/quest), không phải id đơn ứng tuyển —
  /// thống kê nói về cuộc cạnh tranh ở tin đó, và nhiều người cùng xem chung
  /// một con số.
  Future<String?> unlockInsight(String targetId, {required bool isQuest}) =>
      _spend('/premium/insight/unlock?targetId=$targetId'
          '&applicationType=${isQuest ? 'QUEST' : 'JOB'}');

  /// Đọc số liệu Insight của một tin.
  ///
  /// Gọi được cả khi CHƯA mở khoá: backend trả `unlocked: false` kèm tổng số
  /// ứng viên, còn thứ hạng và phân vị thì về 0. Nhờ vậy màn hình khoe được
  /// một con số thật trước khi mời trả tiền, thay vì một ô trống.
  Future<InsightData?> insight(String targetId, {required bool isQuest}) async {
    try {
      final res = await _api.get('/premium/insight/$targetId',
          query: {'applicationType': isQuest ? 'QUEST' : 'JOB'});
      return InsightData.fromJson(Map<String, dynamic>.from(res as Map));
    } on ApiException {
      return null;
    }
  }

  /// Đăng ký duyệt nhanh cho một minh chứng đang chờ. Trừ NP.
  Future<String?> expressVerification(String experienceId) =>
      _spend('/premium/express?experienceId=$experienceId');

  Future<String?> _spend(String path, {Object? body}) async {
    try {
      await _api.post(path, body: body);
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
class InsightData {
  const InsightData({
    required this.unlocked,
    required this.totalApplicants,
    required this.averageRs,
    required this.myRank,
    required this.percentile,
  });

  /// Chưa mở khoá thì chỉ `totalApplicants` có nghĩa; các số còn lại về 0.
  final bool unlocked;

  final int totalApplicants;
  final int averageRs;
  final int myRank;

  /// Phần trăm ứng viên mà mình xếp trên. Càng cao càng tốt.
  final int percentile;

  factory InsightData.fromJson(Map<String, dynamic> m) => InsightData(
        unlocked: m['unlocked'] == true,
        totalApplicants: WalletStore._int(m['totalApplicants']),
        averageRs: WalletStore._int(m['averageRs']),
        myRank: WalletStore._int(m['myRank']),
        percentile: WalletStore._int(m['percentile']),
      );
}

/// Thông tin một yêu cầu nạp đang chờ trả tiền.
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
