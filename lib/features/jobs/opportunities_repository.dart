import '../../core/api_client.dart';
import 'opportunity.dart';

class OpportunitiesRepository {
  OpportunitiesRepository(this._api);
  final ApiClient _api;

  /// Bộ nhớ đệm dùng chung cho cả phiên.
  ///
  /// Trang chủ, tab Cơ hội và ô tìm kiếm đều cần cùng một danh sách. Không có
  /// đệm thì mở app gọi API ba lần cho đúng một tập dữ liệu.
  ///
  /// Là static vì repository được tạo mới ở từng màn hình; đặt trong thực thể
  /// thì mỗi màn hình có một bản đệm riêng và chẳng đệm được gì.
  static List<Opportunity>? _cache;

  /// Danh sách đã nạp, hoặc null nếu chưa. Dùng cho nơi cần đọc ngay mà không
  /// muốn gọi mạng — ví dụ ô tìm kiếm.
  static List<Opportunity>? get cached => _cache;

  static void invalidate() => _cache = null;

  /// Nạp tin tuyển dụng và quest, trộn thành một danh sách.
  ///
  /// Gọi song song và chịu lỗi từng phần: /quests hỏng thì vẫn hiện được tin
  /// tuyển dụng, thay vì để người dùng nhìn màn hình trắng. Chỉ khi CẢ HAI
  /// cùng hỏng mới ném lỗi ra ngoài.
  Future<List<Opportunity>> fetchAll({int limit = 60, bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    final jobs = await Future.wait([
      _tryFetch(() => _api.get('/jobs', query: {'limit': limit})),
      _tryFetch(() => _api.get('/quests')),
    ]);

    final jobsRaw = jobs[0];
    final questsRaw = jobs[1];

    if (jobsRaw == null && questsRaw == null) {
      throw ApiException(
        'Không tải được danh sách cơ hội. Kiểm tra backend đã chạy chưa.',
      );
    }

    _cache = <Opportunity>[
      ...?jobsRaw?.whereType<Map<String, dynamic>>().map(Opportunity.fromJob),
      ...?questsRaw?.whereType<Map<String, dynamic>>().map(Opportunity.fromQuest),
    ];
    return _cache!;
  }

  /// Tìm một cơ hội theo id, không cần có sẵn bản tóm tắt.
  ///
  /// Tin tuyển dụng có endpoint riêng (GET /jobs/{id}). Quest thì KHÔNG —
  /// backend chỉ có /organizer/quests/{id} và nó đòi quyền tổ chức — nên phải
  /// dò trong danh sách. Danh sách quest đã mang đủ mọi trường nên không mất gì.
  ///
  /// Trả null khi không còn tồn tại (tin đã đóng, quest đã hết hạn), để nơi
  /// gọi nói được câu tử tế thay vì ném lỗi kỹ thuật.
  Future<Opportunity?> findById(String id, {required bool isQuest}) async {
    if (!isQuest) {
      try {
        final d = await _api.get('/jobs/$id');
        if (d is Map<String, dynamic>) return Opportunity.fromJob(d);
      } on ApiException {
        return null;
      }
      return null;
    }

    final all = await fetchAll();
    for (final o in all) {
      if (o.id == id && o.isQuest) return o;
    }
    return null;
  }

  /// Nạp chi tiết một cơ hội.
  ///
  /// Chỉ tin tuyển dụng mới cần gọi thêm: GET /jobs/{id} trả về `capacity` và
  /// `formFields` mà danh sách không có.
  ///
  /// Quest thì KHÔNG có endpoint chi tiết công khai — backend chỉ có
  /// /organizer/quests/{id} và nó đòi quyền tổ chức. Nhưng danh sách quest đã
  /// trả về đủ mọi trường (kể cả description và formFields), nên không thiếu
  /// gì. Trả lại nguyên bản tóm tắt.
  Future<Opportunity> fetchDetail(Opportunity summary) async {
    if (summary.isQuest) return summary;
    try {
      final data = await _api.get('/jobs/${summary.id}');
      if (data is Map<String, dynamic>) return summary.mergeDetail(data);
    } on ApiException {
      // Không nâng lỗi lên: bản tóm tắt đã đủ để hiển thị gần hết màn hình
      // chi tiết. Chặn cả trang chỉ vì thiếu `capacity` là quá tay.
    }
    return summary;
  }

  /// Nộp đơn. Trả null nếu thành công, hoặc thông điệp lỗi tiếng Việt.
  Future<String?> apply(Opportunity item, String coverNote) async {
    final path = item.isQuest
        ? '/quests/${item.id}/apply'
        : '/jobs/${item.id}/apply';
    try {
      await _api.post(path, body: {'coverNote': coverNote, 'answers': {}});
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// null = nhánh này hỏng. Nuốt lỗi ở đây là CỐ Ý — nơi gọi quyết định có
  /// nghiêm trọng hay không dựa trên việc cả hai cùng null.
  Future<List<dynamic>?> _tryFetch(Future<dynamic> Function() run) async {
    try {
      final v = await run();
      return v is List ? v : <dynamic>[];
    } on ApiException {
      return null;
    }
  }
}
