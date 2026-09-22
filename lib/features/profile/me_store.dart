import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';

/// Hồ sơ ứng viên đang đăng nhập — nguồn cho việc khớp cơ hội và cho các lời
/// nhắc trên trang chủ.
///
/// Vì sao KHÔNG dùng `/premium/recommendations`: endpoint đó bị chặn sau gói
/// Job Match Alert (trả 402 MATCH_ALERT_REQUIRED). Trang chủ là màn hình đầu
/// tiên của mọi người dùng, kể cả người chưa trả tiền, nên nó không thể dựng
/// trên một nguồn mà phần lớn người dùng không gọi được. Bù lại, `/jobs` và
/// `/quests` đã trả kèm danh sách kỹ năng của từng tin, nên phép khớp cơ bản
/// (giao kỹ năng) làm được ngay ở client với đúng dữ liệu đó.
class MeStore extends ChangeNotifier {
  MeStore._();
  static final instance = MeStore._();

  final _api = ApiClient();

  String? name;
  String? headline;
  String? school;
  String? avatarUrl;
  int reputationScore = 0;
  bool openToWork = false;
  bool onboardingCompleted = false;

  /// Đã hạ về chữ thường để SO KHỚP. Tên kỹ năng do người dùng và nhà tuyển
  /// dụng tự nhập nên không tin được vào cách viết hoa.
  ///
  /// CHỈ dùng để so khớp. Muốn HIỂN THỊ thì lấy `skillLabels` — in ra bản
  /// thường hoá sẽ biến "JavaScript" thành "Javascript" và "SQL" thành "Sql".
  Set<String> skills = const {};

  /// Số dư NP. Đọc từ bản gốc chứ không nhân đôi thành trường riêng —
  /// /profiles/me đã trả sẵn, và một trường nữa là một chỗ nữa có thể quên
  /// cập nhật trong clear().
  int get npBalance => _int(raw['npBalance']);

  /// Cấp độ và tổng EXP theo hồ sơ. GamificationStore cũng có cấp độ, nhưng
  /// nó lấy từ /me/gamification và có thể chưa nạp; hai nguồn này luôn khớp
  /// vì cùng tính từ tổng EXP.
  int get currentLevel => _int(raw['currentLevel']);
  int get totalExp => _int(raw['totalExp']);

  /// Đường dẫn hồ sơ công khai, null nếu người dùng chưa đặt.
  String? get publicSlug => _str(raw['publicSlug']);

  /// Kỹ năng đúng cách viết người dùng đã nhập, để hiển thị.
  List<String> get skillLabels {
    final v = raw['skills'];
    if (v is! List) return const [];
    return v
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String? bio;
  String? location;

  /// Bản gốc nguyên vẹn của phản hồi /profiles/me.
  ///
  /// BẮT BUỘC phải giữ. `PUT /profiles/me` nhận trọn bộ PortfolioRequest và
  /// GHI ĐÈ tất cả — gửi thiếu `experiences` là xoá sạch kinh nghiệm, thiếu
  /// `avatar` là mất ảnh. Màn sửa hồ sơ chỉ đụng vài trường, nên nó phải dựng
  /// payload TỪ bản gốc này rồi mới chèn phần đã sửa lên.
  ///
  /// Đây đúng là lỗi đã xảy ra một lần ở trang doanh nghiệp bên web: handleSave
  /// bỏ sót logoUrl/schoolId/advisorContact nên mỗi lần lưu là xoá chúng.
  Map<String, dynamic> raw = const {};

  /// Giữ NGUYÊN danh sách chứ không chỉ đếm: trang Hồ sơ năng lực cần nội
  /// dung, còn trang chủ chỉ cần số lượng — nạp một lần dùng được cả hai.
  List<Map<String, dynamic>> experienceList = const [];
  List<Map<String, dynamic>> credentialList = const [];

  int get experiences => experienceList.length;
  int get credentials => credentialList.length;

  /// Tên hiển thị đầy đủ. Kỹ năng, kinh nghiệm… đều đã có getter riêng.
  bool loaded = false;

  /// Các việc còn thiếu trong hồ sơ, theo thứ tự ảnh hưởng đến kết quả khớp.
  /// Kỹ năng đứng đầu vì thiếu nó thì phép khớp không chạy được chút nào.
  List<String> get missing => [
        if (skills.isEmpty) 'kỹ năng',
        if (headline == null || headline!.trim().isEmpty) 'giới thiệu ngắn',
        if (school == null || school!.trim().isEmpty) 'trường',
        if (experiences == 0) 'kinh nghiệm',
        if (credentials == 0) 'chứng chỉ',
      ];

  /// 0..1. Năm mục, mỗi mục một phần bằng nhau — cố ý không chấm điểm theo
  /// trọng số, vì con số ở đây chỉ để nhắc, không phải để xếp hạng ai.
  double get completeness => (5 - missing.length) / 5;

  Future<void> hydrate() async {
    try {
      final data = await _api.get('/profiles/me');
      if (data is! Map) return;
      raw = Map<String, dynamic>.from(data);
      name = _str(data['name']);
      location = _str(data['location']);
      headline = _str(data['headline']);
      school = _str(data['school']);
      avatarUrl = _str(data['avatarUrl']);
      reputationScore = _int(data['reputationScore']);
      openToWork = data['openToWork'] == true;
      onboardingCompleted = data['onboardingCompleted'] == true;
      skills = (data['skills'] as List?)
              ?.whereType<String>()
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .toSet() ??
          const {};
      bio = _str(data['bio']);
      experienceList = (data['experiences'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [];
      credentialList = (data['credentials'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [];
      loaded = true;
      notifyListeners();
    } on ApiException {
      // Khách hoặc hồ sơ chưa khởi tạo: trang chủ vẫn chạy, chỉ là không khớp
      // theo kỹ năng được. Không phải sự cố cần báo.
    }
  }

  void clear() {
    name = headline = school = avatarUrl = bio = location = null;
    raw = const {};
    reputationScore = 0;
    openToWork = onboardingCompleted = loaded = false;
    skills = const {};
    experienceList = const [];
    credentialList = const [];
    notifyListeners();
  }

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
}
