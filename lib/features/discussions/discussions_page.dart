import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'compose_post_page.dart';
import 'discussion_models.dart';
import 'discussion_widgets.dart';
import 'discussions_repository.dart';
import 'post_detail_page.dart';

/// Tab Thảo luận.
///
/// ─── Vì sao bản trước bị bỏ ──────────────────────────────────────────────
/// Nó xếp SÁU chủ đề thành sáu thẻ chữ nhật giống hệt nhau, rồi mới tới bài
/// viết — người dùng phải cuộn qua một bức tường thẻ trước khi thấy nội dung,
/// và không thẻ nào bấm được dù có mũi tên. Bài viết thì đọc post['title'] và
/// post['excerpt'], hai trường KHÔNG tồn tại, nên mọi bài đều hiện "Không có
/// tiêu đề". Và cả tab chỉ đọc: không thích, không bình luận, không đăng.
///
/// ─── Bản này ─────────────────────────────────────────────────────────────
///   1. Chủ đề thành một hàng chip cuộn ngang và LỌC được feed, thay cho sáu
///      thẻ chiếm trọn màn hình đầu.
///   2. Feed ngăn bằng ĐƯỜNG KẺ mảnh chứ không phải thẻ nổi. Cả app đã dùng
///      thẻ ở mọi nơi; một dòng thảo luận không phải một mẩu dữ liệu, nó là
///      lời của một người — và cách trình bày nên nói ra điều đó.
///   3. Thích, bình luận, bình chọn, đăng bài đều chạy thật.
class DiscussionsPage extends StatefulWidget {
  const DiscussionsPage({
    super.key,
    required this.isGuest,
    required this.onSignIn,
  });

  final bool isGuest;
  final VoidCallback onSignIn;

  @override
  State<DiscussionsPage> createState() => _DiscussionsPageState();
}

class _DiscussionsPageState extends State<DiscussionsPage> {
  late final _repo = DiscussionsRepository(ApiClient());

  List<DiscussionTopic> _topics = const [];
  List<DiscussionPost> _posts = const [];

  /// null = tất cả chủ đề.
  String? _topic;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DiscussionsPage old) {
    super.didUpdateWidget(old);
    // Đăng nhập xong thì `hasLiked` và `isMine` mới có giá trị thật — trước đó
    // backend trả false cho tất cả vì không biết người gọi là ai.
    if (old.isGuest != widget.isGuest) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await Future.wait([
        _repo.topics(),
        _repo.posts(topic: _topic),
      ]);
      if (!mounted) return;
      setState(() {
        _topics = res[0] as List<DiscussionTopic>;
        _posts = res[1] as List<DiscussionPost>;
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

  Future<void> _pickTopic(String? slug) async {
    setState(() {
      _topic = slug;
      _loading = true;
    });
    try {
      final list = await _repo.posts(topic: slug);
      if (mounted) {
        setState(() {
          _posts = list;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  /// Thích: đổi giao diện trước, trả lại nếu máy chủ từ chối. Chờ mạng xong
  /// mới tô tim thì trên 3G cú bấm trông như trượt.
  Future<void> _toggleLike(DiscussionPost post) async {
    if (widget.isGuest) return widget.onSignIn();

    final before = post;
    _replace(post.copyWith(
      hasLiked: !post.hasLiked,
      likes: post.likes + (post.hasLiked ? -1 : 1),
    ));

    try {
      final (liked, count) = await _repo.toggleLike(post.id);
      if (mounted) {
        _replace(post.copyWith(hasLiked: liked, likes: count));
      }
    } on ApiException {
      if (mounted) _replace(before);
    }
  }

  void _replace(DiscussionPost next) {
    final i = _posts.indexWhere((p) => p.id == next.id);
    if (i < 0) return;
    setState(() => _posts = [..._posts]..[i] = next);
  }

  Future<void> _compose() async {
    if (widget.isGuest) return widget.onSignIn();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ComposePostPage(topics: _topics, initialTopic: _topic),
      ),
    );
    if (created == true && mounted) await _load();
  }

  void _open(DiscussionPost post) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailPage(
            post: post,
            isGuest: widget.isGuest,
            onSignIn: widget.onSignIn,
            onChanged: _replace,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: c.acidText,
          backgroundColor: c.surfaceHi,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Np.gutter, Np.s4, Np.gutter, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionLabel('Cộng đồng'),
                            const SizedBox(height: Np.s2),
                            Text('Thảo luận',
                                style: NpType.h1.copyWith(color: c.ink)),
                          ],
                        ),
                      ),
                      _ComposeButton(onTap: _compose),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: Np.s5, bottom: Np.s4),
                  child: SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: Np.gutter),
                      children: [
                        _TopicChip(
                          label: 'Tất cả',
                          on: _topic == null,
                          onTap: () => _pickTopic(null),
                        ),
                        for (final t in _topics) ...[
                          const SizedBox(width: Np.s2),
                          _TopicChip(
                            label: t.name,
                            on: _topic == t.slug,
                            onTap: () => _pickTopic(t.slug),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              if (_error != null)
                SliverToBoxAdapter(child: _Message(text: _error!, danger: true))
              else if (_loading)
                const SliverToBoxAdapter(
                    child: _Message(text: 'Đang tải…'))
              else if (_posts.isEmpty)
                SliverToBoxAdapter(
                  child: _Empty(
                    topic: _topic == null
                        ? null
                        : _topics
                            .where((t) => t.slug == _topic)
                            .map((t) => t.name)
                            .firstOrNull,
                    onCompose: _compose,
                  ),
                )
              else
                SliverList.separated(
                  itemCount: _posts.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: c.line, height: 1, thickness: 1),
                  itemBuilder: (_, i) => _PostTile(
                    post: _posts[i],
                    onTap: () => _open(_posts[i]),
                    onLike: () => _toggleLike(_posts[i]),
                  ),
                ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: Np.navInset)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút soạn bài. Nằm cạnh tiêu đề chứ không phải nút nổi góc dưới: góc dưới
/// bên phải đã có nút tìm kiếm của thanh điều hướng, hai nút tròn chồng khu
/// vực nhau là chỗ bấm nhầm.
class _ComposeButton extends StatelessWidget {
  const _ComposeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s2 + 2),
        decoration: BoxDecoration(
          color: c.acid,
          borderRadius: BorderRadius.circular(Np.rPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NpIco(NpIcon.send, size: 15, color: c.onAcid),
            const SizedBox(width: Np.s2),
            Text('Viết bài',
                style: NpType.meta.copyWith(
                  fontSize: 13.5,
                  color: c.onAcid,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Np.s4),
        decoration: BoxDecoration(
          color: on ? c.band : c.surface,
          borderRadius: BorderRadius.circular(Np.rPill),
          border: Border.all(color: on ? c.band : c.line),
        ),
        child: Text(label,
            style: NpType.meta.copyWith(
              fontSize: 13.5,
              color: on ? c.onBand : c.ink,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}

/// Một bài trong feed.
class _PostTile extends StatelessWidget {
  const _PostTile({
    required this.post,
    required this.onTap,
    required this.onLike,
  });

  final DiscussionPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s5, Np.gutter, Np.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(name: post.authorName, url: post.authorAvatarUrl),
            const SizedBox(width: Np.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthorLine(post: post),
                  if (post.authorRole.isNotEmpty)
                    Text(post.authorRole,
                        style: NpType.meta
                            .copyWith(fontSize: 12, color: c.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),

                  const SizedBox(height: Np.s3),
                  Text(post.headline,
                      style: NpType.body.copyWith(
                        fontSize: 15.5,
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.38,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  if (post.rest.isNotEmpty) ...[
                    const SizedBox(height: Np.s2),
                    Text(post.rest,
                        style: NpType.body.copyWith(
                            fontSize: 14, color: c.muted, height: 1.45),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ],

                  if (post.poll != null) ...[
                    const SizedBox(height: Np.s4),
                    // Trong feed thì khảo sát chỉ để XEM; muốn bỏ phiếu phải
                    // mở bài. Bỏ phiếu ngay giữa lúc lướt thì dễ bấm nhầm, mà
                    // phiếu thì không đổi lại được.
                    PollBox(poll: post.poll!, onVote: null),
                  ],

                  const SizedBox(height: Np.s2),
                  Row(
                    children: [
                      PostAction(
                        icon: post.hasLiked ? NpIcon.heartFill : NpIcon.heart,
                        count: post.likes,
                        active: post.hasLiked,
                        onTap: onLike,
                      ),
                      const SizedBox(width: Np.s5),
                      PostAction(
                          icon: NpIcon.chat,
                          count: post.comments,
                          onTap: onTap),
                      const Spacer(),
                      if (post.topicName.isNotEmpty)
                        Text(post.topicName,
                            style: NpType.meta
                                .copyWith(fontSize: 11.5, color: c.faint)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.topic, required this.onCompose});
  final String? topic;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s10, Np.gutter, Np.s10),
      child: Column(
        children: [
          NpIco(NpIcon.chat, size: 26, color: c.faint),
          const SizedBox(height: Np.s4),
          Text(
            topic == null
                ? 'Chưa có bài nào.'
                : 'Chưa có bài nào trong "$topic".',
            style: NpType.title.copyWith(fontSize: 17, color: c.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Np.s2),
          Text('Bạn mở đầu nhé?',
              style: NpType.meta.copyWith(color: c.muted)),
          const SizedBox(height: Np.s5),
          AcidButton(label: 'Viết bài', onTap: onCompose, expand: false),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.danger = false});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s10, Np.gutter, Np.s10),
      child: Text(text,
          style: NpType.meta.copyWith(color: danger ? c.danger : c.muted),
          textAlign: TextAlign.center),
    );
  }
}
