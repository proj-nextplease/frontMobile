import 'dart:convert';

/// Một minh chứng đã nộp.
///
/// "Minh chứng" là thứ biến hồ sơ từ tự khai thành có bằng chứng: người dùng
/// nộp một hoạt động đã làm kèm ảnh, admin duyệt, rồi nó được cộng EXP và
/// điểm uy tín, đồng thời gắn dấu đã xác thực trên hồ sơ.
class Credential {
  const Credential({
    required this.id,
    required this.projectName,
    required this.position,
    required this.category,
    required this.roleLevel,
    required this.status,
    this.description,
    this.proofLink,
    this.rejectReason,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.proofImages = const [],
    this.express = false,
  });

  final String id;
  final String projectName;
  final String position;
  final String category;
  final String roleLevel;

  /// PENDING · APPROVED · REJECTED · NEEDS_MORE_EVIDENCE
  /// (ràng buộc ck_experiences_verification_status).
  final String status;

  final String? description;
  final String? proofLink;
  final String? rejectReason;
  final String? startedAt;
  final String? endedAt;
  final DateTime? createdAt;
  final List<String> proofImages;
  final bool express;

  factory Credential.fromJson(Map<String, dynamic> m) => Credential(
        id: '${m['id']}',
        projectName: _str(m['project_name']) ?? 'Hoạt động',
        position: _str(m['position']) ?? '',
        category: '${m['category'] ?? ''}',
        roleLevel: '${m['role_level'] ?? ''}',
        status: '${m['verification_status'] ?? 'PENDING'}'.toUpperCase(),
        description: _str(m['description']),
        proofLink: _str(m['proof_link']),
        rejectReason: _str(m['reject_reason']),
        startedAt: _str(m['started_at']),
        endedAt: _str(m['ended_at']),
        createdAt: m['created_at'] == null
            ? null
            : DateTime.tryParse('${m['created_at']}')?.toLocal(),
        proofImages: _images(m['proof_images']),
        express: m['expressVerification'] == true,
      );

  /// `proof_images` về dưới dạng CHUỖI JSON, không phải mảng — truy vấn ép
  /// `proof_images::text` trước khi trả. Đọc thẳng như List sẽ luôn ra rỗng
  /// mà không ném lỗi, đúng kiểu bẫy đã gặp ở statusHistory của đơn ứng tuyển.
  static List<String> _images(Object? v) {
    if (v is List) return v.whereType<String>().toList();
    if (v is! String || v.isEmpty) return const [];
    try {
      final raw = jsonDecode(v);
      return raw is List ? raw.whereType<String>().toList() : const [];
    } on FormatException {
      return const [];
    }
  }

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}

/// Nhãn tiếng Việt cho trạng thái duyệt.
String credentialStatusLabel(String s) => switch (s) {
      'PENDING' => 'Chờ duyệt',
      'APPROVED' => 'Đã xác thực',
      'REJECTED' => 'Bị từ chối',
      'NEEDS_MORE_EVIDENCE' => 'Cần bổ sung',
      _ => s.isEmpty ? 'Không rõ' : s,
    };

/// Loại hình hoạt động. Mã lấy từ ràng buộc ck_experiences_category —
/// gửi mã ngoài danh sách này thì Postgres từ chối cả câu insert.
const kCredentialCategories = <String, String>{
  'CLUB_SMALL': 'Hoạt động CLB',
  'SCHOOL_CAMPAIGN': 'Chiến dịch trường',
  'COMPANY_PROJECT': 'Dự án doanh nghiệp',
  'SHORT_INTERNSHIP': 'Thực tập ngắn hạn',
  'FREELANCE_GIG': 'Việc tự do',
  'QUEST': 'Quest trên nextplease',
};

/// Cấp bậc vai trò (ck_experiences_role_level).
const kRoleLevels = <String, String>{
  'MEMBER': 'Thành viên',
  'LEADER': 'Trưởng nhóm / phụ trách',
};

String categoryLabel(String code) => kCredentialCategories[code] ?? code;
String roleLevelLabel(String code) => kRoleLevels[code] ?? code;
