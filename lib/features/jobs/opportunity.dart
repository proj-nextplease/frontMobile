/// Một "cơ hội" — gộp chung tin tuyển dụng và quest.
///
/// Web đã đi đúng đường này ở trang /jobs: trộn hai nguồn vào một danh sách
/// rồi mang theo cờ phân biệt. Làm y vậy ở mobile để hai bên không lệch nhau.
///
/// Vì sao viết model bằng tay thay vì sinh từ OpenAPI: backend khai báo
/// GET /jobs và GET /quests trả về `Map<String,Object>` thô, nên đặc tả chỉ mô
/// tả chúng là "object rỗng" — sinh code ra cũng chỉ được `Map<String,dynamic>`.
/// Các trường dưới đây lấy từ payload THẬT của hai endpoint đó.
/// `external` = tin tổng hợp từ nguồn ngoài (Careerjet). Không có bản ghi
/// trong DB của nextplease nên không ứng tuyển, không lưu, không cộng Proof —
/// bấm vào là mở trang gốc của nhà tuyển dụng.
enum OpportunityKind { job, quest, external }

class Opportunity {
  const Opportunity({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.companyName,
    required this.isClub,
    this.companyId,
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
    this.applyUrl,
    this.externalSalary,
  });

  final String id;
  final OpportunityKind kind;
  final String title;
  final String description;
  final String companyName;

  /// Dùng để mở trang công ty. Có thể null với dữ liệu cũ, nên mọi nơi dùng
  /// phải chịu được việc không có nó.
  final String? companyId;
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

  /// Chỉ có với [OpportunityKind.external]: link tới tin gốc.
  final String? applyUrl;

  /// Lương đã dựng sẵn cho tin ngoài, ví dụ "5 - 6 triệu / tháng".
  ///
  /// Không nhét vào [compensation] vì đó là một CON SỐ, mà Careerjet cho một
  /// KHOẢNG. Lấy số đầu khoảng rồi hiển thị như lương chính xác là nói sai:
  /// tin "5 - 6 triệu" sẽ hiện thành "5 triệu".
  final String? externalSalary;

  /// Tin ngoài không tạo được bản ghi ứng tuyển, nên mọi thứ gắn với hồ sơ —
  /// theo dõi đơn, cộng RS/EXP, Proof — đều không áp dụng.
  bool get isExternal => kind == OpportunityKind.external;

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
        companyId: _id(d['companyId']) ?? companyId,
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
        companyId: _id(j['companyId']),
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

  /// Tin nguồn ngoài, đưa về cùng hình dạng để nằm chung một danh sách với
  /// tin thật — giống cách quest đã làm. Web cũng trộn chung ở trang /jobs.
  factory Opportunity.fromExternal(Map<String, dynamic> e) => Opportunity(
        // Tiền tố 'ext:' để id không đụng id thật. Hai nguồn dùng chung một
        // danh sách nên trùng id là thẻ này ghi đè thẻ kia khi Flutter dựng
        // lại cây widget theo key.
        id: 'ext:${e['id']}',
        kind: OpportunityKind.external,
        title: (e['title'] ?? 'Chưa đặt tên') as String,
        description: (e['excerpt'] ?? '') as String,
        companyName: (e['companyName'] ?? 'Nhà tuyển dụng') as String,
        isClub: false,
        location: e['location'] as String?,
        createdAt: _parseDate(e['postedAt']),
        applyUrl: e['applyUrl'] as String?,
        externalSalary: _externalSalary(e),
      );

  /// Careerjet trả lương dạng chuỗi tiếng Anh ("₫5000000 - 6000000 per month")
  /// kèm salaryMin/Max/Type. Dựng lại bằng tiếng Việt từ các số đó; không đủ
  /// số thì trả null để thẻ nói "Lương không công khai" thay vì bịa.
  static String? _externalSalary(Map<String, dynamic> e) {
    const unit = {'Y': 'năm', 'M': 'tháng', 'W': 'tuần', 'D': 'ngày', 'H': 'giờ'};
    final suffix = unit[e['salaryType']] == null ? '' : ' / ${unit[e['salaryType']]}';
    String? short(Object? v) {
      final n = v is num ? v : num.tryParse('$v');
      if (n == null || n <= 0) return null;
      if (n >= 1000000) {
        final t = n / 1000000;
        return '${t.toStringAsFixed(t.truncateToDouble() == t ? 0 : 1)} triệu';
      }
      return '${n.toStringAsFixed(0)} đ';
    }
    final lo = short(e['salaryMin']);
    final hi = short(e['salaryMax']);
    if (lo != null && hi != null && lo != hi) return '$lo - $hi$suffix';
    if (lo != null) return '$lo$suffix';
    return null;
  }

  factory Opportunity.fromQuest(Map<String, dynamic> q) => Opportunity(
        id: '${q['id']}',
        kind: OpportunityKind.quest,
        title: (q['title'] ?? 'Chưa đặt tên') as String,
        description: (q['description'] ?? '') as String,
        companyName: (q['companyName'] ?? 'CLB / Tổ chức') as String,
        isClub: q['companyType'] == 'CLUB',
        companyId: _id(q['companyId']),
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
        // Quest cũng có chế độ Premium từ V54. Thiếu dòng này thì Quest
        // Premium mất nhãn trên app dù tin đang bật.
        requiresPremium: q['requiresPremium'] == true,
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

/// Ép về chuỗi id, coi chuỗi rỗng là không có. '${null}' ra "null" nên không
/// thể nội suy thẳng.
String? _id(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return (s.isEmpty || s == 'null') ? null : s;
}
