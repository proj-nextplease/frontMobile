import '../../core/api_client.dart';
import 'discussion_models.dart';

/// Gọi API cho tab Thảo luận.
class DiscussionsRepository {
  DiscussionsRepository(this._api);
  final ApiClient _api;

  Future<List<DiscussionTopic>> topics() async {
    final d = await _api.get('/discussions/topics');
    return _list(d).map(DiscussionTopic.fromJson).toList();
  }

  /// `topic` là SLUG, không phải tên hiển thị — backend lọc theo `t.slug`.
  Future<List<DiscussionPost>> posts({String? topic, String? sort}) async {
    final d = await _api.get('/discussions/posts', query: {
      if (topic != null && topic.isNotEmpty) 'topic': topic,
      'sort': ?sort,
      'limit': 50,
    });
    return _list(d).map(DiscussionPost.fromJson).toList();
  }

  /// Một bài theo id. Cần cho việc mở bài từ thông báo — bài đó có thể nằm
  /// ngoài trang đầu của feed, nên lọc lại danh sách là không đủ.
  Future<DiscussionPost> fetchPost(String id) async {
    final d = await _api.get('/discussions/posts/$id');
    if (d is! Map<String, dynamic>) {
      throw ApiException('Không tìm thấy bài viết này.');
    }
    return DiscussionPost.fromJson(d);
  }

  Future<List<DiscussionComment>> comments(String postId) async {
    final d = await _api.get('/discussions/posts/$postId/comments');
    return _list(d).map(DiscussionComment.fromJson).toList();
  }

  /// Trả về (hasLiked, likesCount) sau khi đổi.
  Future<(bool, int)> toggleLike(String postId) async {
    final d = await _api.post('/discussions/posts/$postId/like');
    final m = d is Map<String, dynamic> ? d : const <String, dynamic>{};
    return (m['hasLiked'] == true, (m['likesCount'] as num?)?.toInt() ?? 0);
  }

  Future<DiscussionComment> addComment(String postId, String content) async {
    final d = await _api.post('/discussions/posts/$postId/comments',
        body: {'content': content});
    return DiscussionComment.fromJson(
        d is Map<String, dynamic> ? d : const <String, dynamic>{});
  }

  Future<void> createPost({
    required String topicSlug,
    required String content,
    List<String>? pollOptions,
  }) =>
      _api.post('/discussions/posts', body: {
        'topic': topicSlug,
        'content': content,
        // Bỏ hẳn khoá khi không có lựa chọn nào, thay vì gửi mảng rỗng:
        // normalizePollOptions phía backend coi mảng 1 phần tử là lỗi, và một
        // mảng rỗng đi qua đó thì không có gì bảo đảm vẫn im lặng.
        if (pollOptions != null && pollOptions.isNotEmpty)
          'pollOptions': pollOptions,
      });

  Future<DiscussionPoll?> vote(String postId, String optionId) async {
    final d = await _api.post('/discussions/posts/$postId/vote',
        body: {'optionId': optionId});
    return d is Map<String, dynamic> ? DiscussionPoll.fromJson(d) : null;
  }

  Future<void> deletePost(String postId) =>
      _api.delete('/discussions/posts/$postId');

  /// Phản hồi có thể là mảng thẳng hoặc object bọc {items|content}. Nhận cả
  /// hai thay vì giả định một kiểu — backend trả Map thô nên hình dạng không
  /// có gì bảo đảm.
  List<Map<String, dynamic>> _list(dynamic v) {
    final raw = v is List
        ? v
        : (v is Map ? (v['items'] ?? v['content'] ?? const []) : const []);
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}
