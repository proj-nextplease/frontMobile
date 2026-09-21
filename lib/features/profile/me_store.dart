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

  /// Đã hạ về chữ thường để so khớp. Tên kỹ năng do người dùng và nhà tuyển
  /// dụng tự nhập nên không tin được vào cách viết hoa.
  Set<String> skills = const {};

  String? bio;

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
      name = _str(data['name']);
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
    name = headline = school = avatarUrl = bio = null;
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
