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
