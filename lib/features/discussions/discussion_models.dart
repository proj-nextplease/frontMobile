/// Mô hình cho tab Thảo luận.
///
/// Viết tay vì backend khai báo các endpoint này trả `Map<String,Object>` thô,
/// nên đặc tả OpenAPI chỉ mô tả chúng là "object rỗng". Các trường dưới đây
/// lấy từ truy vấn THẬT trong DiscussionService.
class DiscussionTopic {
  const DiscussionTopic({
    required this.id,
    required this.slug,
    required this.name,
    this.postsCount = 0,
    this.official = false,
  });

  final String id;
  final String slug;
  final String name;
  final int postsCount;
  final bool official;

  factory DiscussionTopic.fromJson(Map<String, dynamic> m) => DiscussionTopic(
        id: '${m['id']}',
        slug: '${m['slug'] ?? ''}',
        name: '${m['name'] ?? 'Chủ đề'}',
        postsCount: (m['postsCount'] as num?)?.toInt() ?? 0,
        official: m['official'] == true,
      );
}

class DiscussionPost {
  const DiscussionPost({
    required this.id,
    required this.content,
    required this.authorName,
    required this.authorRole,
    required this.topicName,
    required this.topicSlug,
    required this.likes,
    required this.comments,
    required this.hasLiked,
    required this.isMine,
    this.authorAvatarUrl,
    this.createdAt,
    this.poll,
    this.previewComments = const [],
  });

  final String id;

  /// Bảng KHÔNG có cột tiêu đề — chỉ `content`. Dòng đầu là thứ người viết đặt
  /// làm tiêu đề, nên giao diện tách nó ra chứ không bịa thêm trường.
  final String content;

  final String authorName;
  final String authorRole;
  final String? authorAvatarUrl;
  final String topicName;
  final String topicSlug;
  final int likes;
  final int comments;
  final bool hasLiked;
  final bool isMine;
  final DateTime? createdAt;
  final DiscussionPoll? poll;
  final List<DiscussionComment> previewComments;

  String get headline {
    final first = content.split('\n').first.trim();
    return first.isEmpty ? content.trim() : first;
  }

  /// Phần còn lại sau dòng đầu. Rỗng khi bài chỉ có một dòng.
  String get rest {
    final i = content.indexOf('\n');
    return i < 0 ? '' : content.substring(i + 1).trim();
  }

  factory DiscussionPost.fromJson(Map<String, dynamic> m) => DiscussionPost(
        id: '${m['id']}',
        content: '${m['content'] ?? ''}'.trim(),
        authorName: '${m['authorName'] ?? 'Ẩn danh'}',
        authorRole: '${m['authorRole'] ?? ''}',
        authorAvatarUrl: _url(m['authorAvatarUrl']),
        topicName: '${m['topicName'] ?? ''}',
        topicSlug: '${m['topicSlug'] ?? ''}',
        likes: (m['likesCount'] as num?)?.toInt() ?? 0,
        comments: (m['commentsCount'] as num?)?.toInt() ?? 0,
        hasLiked: m['hasLiked'] == true,
        isMine: m['isMine'] == true,
        createdAt: m['createdAt'] == null
            ? null
            : DateTime.tryParse('${m['createdAt']}')?.toLocal(),
        poll: m['poll'] is Map<String, dynamic>
            ? DiscussionPoll.fromJson(m['poll'] as Map<String, dynamic>)
            : null,
        previewComments: (m['comments'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(DiscussionComment.fromJson)
                .toList() ??
            const [],
      );

  DiscussionPost copyWith({
    int? likes,
    int? comments,
    bool? hasLiked,
    DiscussionPoll? poll,
  }) =>
      DiscussionPost(
        id: id,
        content: content,
        authorName: authorName,
        authorRole: authorRole,
        authorAvatarUrl: authorAvatarUrl,
        topicName: topicName,
        topicSlug: topicSlug,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        hasLiked: hasLiked ?? this.hasLiked,
        isMine: isMine,
        createdAt: createdAt,
        poll: poll ?? this.poll,
        previewComments: previewComments,
      );

  /// `avatar_url` trong DB có thể là data URL base64 (web lưu ảnh kiểu đó).
  /// Image.network KHÔNG tải được `data:` và thất bại IM LẶNG, nên loại thẳng
  /// ở đây để nơi hiển thị rơi về chữ cái đầu thay vì một ô trống.
  static String? _url(Object? v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty || s.startsWith('data:')) return null;
    return s;
  }
}

class DiscussionPoll {
  const DiscussionPoll({
    required this.options,
    required this.totalVotes,
    this.votedOptionId,
  });

  final List<PollOption> options;
  final int totalVotes;
  final String? votedOptionId;

  bool get hasVoted => votedOptionId != null;

  factory DiscussionPoll.fromJson(Map<String, dynamic> m) => DiscussionPoll(
        options: (m['options'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(PollOption.fromJson)
                .toList() ??
            const [],
        totalVotes: (m['totalVotes'] as num?)?.toInt() ?? 0,
        votedOptionId:
            m['votedOption'] == null ? null : '${m['votedOption']}',
      );
}

class PollOption {
  const PollOption({required this.id, required this.text, required this.votes});
  final String id;
  final String text;
  final int votes;

  factory PollOption.fromJson(Map<String, dynamic> m) => PollOption(
        id: '${m['id']}',
        text: '${m['text'] ?? ''}',
        votes: (m['votes'] as num?)?.toInt() ?? 0,
      );

  /// Tỉ lệ 0..1. Chia cho 0 ở đây sẽ ra NaN và Flutter vẽ thanh rộng vô hạn.
  double share(int total) => total <= 0 ? 0 : votes / total;
}

class DiscussionComment {
  const DiscussionComment({
    required this.id,
    required this.author,
    required this.role,
    required this.content,
    this.createdAt,
  });

  final String id;
  final String author;
  final String role;
  final String content;
  final DateTime? createdAt;

  factory DiscussionComment.fromJson(Map<String, dynamic> m) =>
      DiscussionComment(
        id: '${m['id']}',
        author: '${m['author'] ?? 'Ẩn danh'}',
        role: '${m['role'] ?? ''}',
        content: '${m['content'] ?? ''}'.trim(),
        createdAt: m['createdAt'] == null
            ? null
            : DateTime.tryParse('${m['createdAt']}')?.toLocal(),
      );
}
