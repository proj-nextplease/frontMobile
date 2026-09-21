import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// Tab Thảo luận.
///
/// Hiện chỉ đọc: liệt kê chủ đề và bài viết. Chưa cho đăng bài hay bình luận —
/// những việc đó cần trình soạn thảo và luồng kiểm duyệt, làm nửa vời thì tệ
/// hơn không có.
///
/// Backend đang có 6 chủ đề nhưng 0 bài viết, nên phần rỗng ở đây KHÔNG phải
/// trạng thái hiếm gặp — nó là trạng thái mặc định lúc này, và phải nói rõ
/// thay vì để màn hình trắng.
class DiscussionsPage extends StatefulWidget {
  const DiscussionsPage({super.key});

  @override
  State<DiscussionsPage> createState() => _DiscussionsPageState();
}

class _DiscussionsPageState extends State<DiscussionsPage> {
  final _api = ApiClient();

  List<Map<String, dynamic>> _topics = const [];
  List<Map<String, dynamic>> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Future.wait([
        _api.get('/discussions/topics'),
        _api.get('/discussions/posts'),
      ]);
      if (!mounted) return;
      setState(() {
        _topics = _asMaps(res[0]);
        _posts = _asMaps(res[1]);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Phản hồi có thể là mảng thẳng hoặc object bọc {items|content}. Chấp nhận
  /// cả hai thay vì giả định một kiểu — backend trả `Map<String,Object>` thô nên
  /// không có gì bảo đảm hình dạng ổn định.
  List<Map<String, dynamic>> _asMaps(dynamic v) {
    final list = v is List
        ? v
        : (v is Map ? (v['items'] ?? v['content'] ?? const []) : const []);
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Np.gutter, Np.s6, Np.gutter, Np.s10),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SectionLabel('Cộng đồng'),
            const SizedBox(height: Np.s4),
            Text('Thảo luận',
                style: NpType.h1.copyWith(fontSize: 30, color: c.ink)),
            const SizedBox(height: Np.s2),
            Text(
              'Hỏi đáp và chia sẻ kinh nghiệm giữa sinh viên.',
              style: NpType.body.copyWith(color: c.muted),
            ),

            if (_error != null) ...[
              const SizedBox(height: Np.s6),
              _Note(text: _error!, danger: true),
            ],

            if (_topics.isNotEmpty) ...[
              const SizedBox(height: Np.s8),
              const SectionLabel('Chủ đề'),
              const SizedBox(height: Np.s4),
              for (final t in _topics) ...[
                _TopicRow(topic: t),
                const SizedBox(height: Np.s2),
              ],
            ],

            const SizedBox(height: Np.s8),
            const SectionLabel('Bài viết'),
            const SizedBox(height: Np.s4),

            if (_loading)
              Container(height: 110, decoration: Np.card(c))
            else if (_posts.isEmpty)
              const _Note(
                text: 'Chưa có bài viết nào. Hãy là người mở đầu — '
                    'phần đăng bài hiện làm trên website.',
              )
            else
              for (final p in _posts) ...[
                _PostRow(post: p),
                const SizedBox(height: Np.s3),
              ],
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});
  final Map<String, dynamic> topic;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final name = '${topic['name'] ?? 'Chủ đề'}';
    final posts = (topic['postsCount'] as num?)?.toInt() ?? 0;
    final followers = (topic['followersCount'] as num?)?.toInt() ?? 0;
    final official = topic['official'] == true;

    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          style: NpType.title.copyWith(color: c.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (official) ...[
                      const SizedBox(width: Np.s2),
                      const MetaChip(label: 'Chính thức', accent: true),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text('$posts bài · $followers người theo dõi',
                    style: NpType.meta.copyWith(color: c.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.faint, size: 20),
        ],
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post});
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: Np.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${post['title'] ?? 'Không có tiêu đề'}',
              style: NpType.title.copyWith(fontSize: 17, color: c.ink),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: Np.s2),
          Text(
            '${post['excerpt'] ?? post['content'] ?? ''}',
            style: NpType.meta.copyWith(color: c.muted),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.danger = false});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: BoxDecoration(
        color: danger ? c.danger.withValues(alpha: 0.10) : c.surface,
        borderRadius: BorderRadius.circular(Np.rLg),
        border: Border.all(
            color: danger ? c.danger.withValues(alpha: 0.28) : c.line),
      ),
      child: Text(
        text,
        style: NpType.meta.copyWith(color: danger ? c.danger : c.muted),
      ),
    );
  }
}
