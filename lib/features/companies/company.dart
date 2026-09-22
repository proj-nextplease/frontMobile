/// Một đối tác đã được duyệt: doanh nghiệp, CLB, hoặc đơn vị thuộc trường.
class Company {
  const Company({
    required this.id,
    required this.name,
    this.type,
    this.description,
    this.logoUrl,
    this.websiteUrl,
    this.fanpageUrl,
    this.schoolName,
    this.followerCount,
  });

  final String id;
  final String name;

  /// Một trong 7 giá trị mà DB cho phép: STARTUP, SME, AGENCY, CLUB,
  /// EVENT_ORGANIZER, SCHOOL, ENTERPRISE. Chỉ trường này quyết định là CLB
  /// hay doanh nghiệp — tên có chữ "CLB" không phải bằng chứng.
  final String? type;

  final String? description;
  final String? logoUrl;
  final String? websiteUrl;
  final String? fanpageUrl;
  final String? schoolName;

  /// Chỉ /companies/{id} trả về, danh sách thì không.
  final int? followerCount;

  bool get isClub => type == 'CLUB';

  factory Company.fromJson(Map<String, dynamic> m) => Company(
        id: '${m['id']}',
        name: (m['name'] as String?)?.trim().isNotEmpty == true
            ? m['name'] as String
            : 'Đối tác',
        type: m['companyType'] as String?,
        description: _text(m['description']),
        logoUrl: _text(m['logoUrl']),
        websiteUrl: _text(m['websiteUrl']),
        fanpageUrl: _text(m['fanpageUrl']),
        schoolName: _text(m['schoolName']),
        followerCount: (m['followerCount'] as num?)?.toInt(),
      );

  static String? _text(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}

/// Nhãn tiếng Việt cho company_type.
///
/// Bảy mã này là ràng buộc CHECK trong DB (V2), không phải phỏng đoán. Thiếu
/// một mã thì cả nhóm đó rơi về "Đối tác" — một danh bạ mà mọi dòng đều ghi
/// "Đối tác" thì dòng đó không nói gì cả.
String companyTypeLabel(String? type) => switch (type) {
      'CLUB' => 'Câu lạc bộ',
      'SCHOOL' => 'Đơn vị trường',
      'STARTUP' => 'Startup',
      'SME' => 'Doanh nghiệp vừa và nhỏ',
      'ENTERPRISE' => 'Doanh nghiệp lớn',
      'AGENCY' => 'Agency',
      'EVENT_ORGANIZER' => 'Đơn vị tổ chức sự kiện',
      _ => 'Đối tác',
    };
