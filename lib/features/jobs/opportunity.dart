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
      );

  static DateTime? _parseDate(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}
