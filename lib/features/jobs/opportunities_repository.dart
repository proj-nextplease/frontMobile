import '../../core/api_client.dart';
import 'opportunity.dart';

class OpportunitiesRepository {
  OpportunitiesRepository(this._api);
  final ApiClient _api;

  /// Nạp tin tuyển dụng và quest, trộn thành một danh sách.
  ///
  /// Gọi song song và chịu lỗi từng phần: /quests hỏng thì vẫn hiện được tin
  /// tuyển dụng, thay vì để người dùng nhìn màn hình trắng. Chỉ khi CẢ HAI
  /// cùng hỏng mới ném lỗi ra ngoài.
  Future<List<Opportunity>> fetchAll({int limit = 60}) async {
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

    return <Opportunity>[
      ...?jobsRaw?.whereType<Map<String, dynamic>>().map(Opportunity.fromJob),
      ...?questsRaw?.whereType<Map<String, dynamic>>().map(Opportunity.fromQuest),
    ];
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
