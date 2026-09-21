/// Một "cơ hội" — gộp chung tin tuyển dụng và quest.
///
/// Web đã đi đúng đường này ở trang /jobs: trộn hai nguồn vào một danh sách
/// rồi mang theo cờ phân biệt. Làm y vậy ở mobile để hai bên không lệch nhau.
///
/// Vì sao viết model bằng tay thay vì sinh từ OpenAPI: backend khai báo
/// GET /jobs và GET /quests trả về `Map<String,Object>` thô, nên đặc tả chỉ mô
/// tả chúng là "object rỗng" — sinh code ra cũng chỉ được `Map<String,dynamic>`.
/// Các trường dưới đây lấy từ payload THẬT của hai endpoint đó.
enum OpportunityKind { job, quest }

class Opportunity {
  const Opportunity({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.companyName,
    required this.isClub,
    this.companyLogo,
    this.location,
    this.isRemote = false,
    this.typeCode,
    this.compensation,
    this.expReward,
    this.npReward,
    this.applicantCount = 0,
    this.createdAt,
    this.capacity,
    this.minReqRs = 0,
    this.deadlineAt,
    this.startsAt,
    this.endsAt,
    this.skills = const [],
    this.requiresPremium = false,
  });

  final String id;
  final OpportunityKind kind;
  final String title;
  final String description;
  final String companyName;
  final bool isClub;
  final String? companyLogo;
  final String? location;
  final bool isRemote;
  final String? typeCode;      // jobType với tin, category với quest
  final num? compensation;
  final int? expReward;
  final int? npReward;
  final int applicantCount;
  final DateTime? createdAt;

  /// Số lượng cần tuyển. Chỉ có ở chi tiết tin tuyển dụng, còn quest thì có
  /// sẵn ngay trong danh sách.
  final int? capacity;

  /// Điểm uy tín tối thiểu. 0 nghĩa là không yêu cầu.
  final int minReqRs;

  final DateTime? deadlineAt;  // tin tuyển dụng
  final DateTime? startsAt;    // quest
  final DateTime? endsAt;      // quest
  final List<String> skills;
  final bool requiresPremium;

  bool get isQuest => kind == OpportunityKind.quest;

  /// Ghép dữ liệu chi tiết lên trên bản tóm tắt đã có.
  ///
  /// Không thay thế hẳn: danh sách mang vài trường mà endpoint chi tiết KHÔNG
  /// trả về (createdAt, applicantsCount), nên ghi đè trọn gói sẽ làm mất chúng.
  Opportunity mergeDetail(Map<String, dynamic> d) => Opportunity(
        id: id,
        kind: kind,
        title: (d['title'] as String?) ?? title,
        description: (d['description'] as String?) ?? description,
        companyName: (d['companyName'] as String?) ?? companyName,
        isClub: isClub,
        companyLogo: (d['companyLogo'] as String?) ?? companyLogo,
        location: (d['location'] as String?) ?? location,
        isRemote: d['isRemote'] == true,
        typeCode: (d['jobType'] as String?) ?? typeCode,
        compensation: (d['compensation'] as num?) ?? compensation,
        expReward: expReward,
        npReward: npReward,
        applicantCount: applicantCount,
        createdAt: createdAt,
        capacity: (d['capacity'] as num?)?.toInt() ?? capacity,
        minReqRs: (d['minReqRs'] as num?)?.toInt() ?? minReqRs,
        deadlineAt: _parseDate(d['deadlineAt']) ?? deadlineAt,
        startsAt: startsAt,
        endsAt: endsAt,
        skills: _parseSkills(d['skills']) ?? skills,
        requiresPremium: d['requiresPremium'] == true || requiresPremium,
      );

  factory Opportunity.fromJob(Map<String, dynamic> j) => Opportunity(
        id: '${j['id']}',
        kind: OpportunityKind.job,
        title: (j['title'] ?? 'Chưa đặt tên') as String,
        description: (j['description'] ?? '') as String,
        companyName: (j['companyName'] ?? 'Nhà tuyển dụng') as String,
        // Chỉ companyType quyết định CLB hay doanh nghiệp. Tên công ty có chữ
        // "CLB" hay job_type là EVENT_STAFF đều KHÔNG phải bằng chứng — đây là
        // lỗi bên web từng mắc.
        isClub: j['companyType'] == 'CLUB',
        companyLogo: j['companyLogo'] as String?,
        location: j['location'] as String?,
        isRemote: j['isRemote'] == true,
        typeCode: j['jobType'] as String?,
        compensation: j['compensation'] as num?,
        applicantCount: (j['applicantsCount'] as num?)?.toInt() ?? 0,
        createdAt: _parseDate(j['createdAt']),
        capacity: (j['capacity'] as num?)?.toInt(),
        minReqRs: (j['minReqRs'] as num?)?.toInt() ?? 0,
        deadlineAt: _parseDate(j['deadlineAt']),
        skills: _parseSkills(j['skills']) ?? const [],
        requiresPremium: j['requiresPremium'] == true,
      );

  factory Opportunity.fromQuest(Map<String, dynamic> q) => Opportunity(
        id: '${q['id']}',
        kind: OpportunityKind.quest,
        title: (q['title'] ?? 'Chưa đặt tên') as String,
        description: (q['description'] ?? '') as String,
        companyName: (q['companyName'] ?? 'CLB / Tổ chức') as String,
        isClub: q['companyType'] == 'CLUB',
        companyLogo: q['companyLogo'] as String?,
        location: q['location'] as String?,
        isRemote: RegExp(r'remote|từ xa', caseSensitive: false)
            .hasMatch((q['location'] ?? '') as String),
        typeCode: q['category'] as String?,
        compensation: null,  // quest trả thưởng bằng EXP/NP chứ không phải tiền
        expReward: (q['expReward'] as num?)?.toInt(),
        npReward: (q['npReward'] as num?)?.toInt(),
        // Số ít, khác hẳn applicantsCount của job. Sai chỗ này thì luôn ra 0.
        applicantCount: (q['applicantCount'] as num?)?.toInt() ?? 0,
        createdAt: _parseDate(q['createdAt']),
        capacity: (q['capacity'] as num?)?.toInt(),
        minReqRs: (q['minReqRs'] as num?)?.toInt() ?? 0,
        startsAt: _parseDate(q['startsAt']),
        endsAt: _parseDate(q['endsAt']),
      );

  static DateTime? _parseDate(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  /// skills về dưới dạng list các object {skillName|name} hoặc list chuỗi, tuỳ
  /// endpoint. Trả null khi không có trường để nơi gọi giữ giá trị cũ.
  static List<String>? _parseSkills(Object? v) {
    if (v is! List) return null;
    return v
        .map((e) {
          if (e is String) return e;
          if (e is Map) return '${e['skillName'] ?? e['name'] ?? ''}';
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
