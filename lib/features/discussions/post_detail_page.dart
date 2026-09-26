import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/opportunity_labels.dart';
import 'discussion_models.dart';
import 'discussion_widgets.dart';
import 'discussions_repository.dart';

/// Một bài thảo luận và toàn bộ bình luận.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    required this.isGuest,
    required this.onSignIn,
    this.onChanged,
  });

  final DiscussionPost post;
  final bool isGuest;
  final VoidCallback onSignIn;

  /// Báo ngược cho feed biết bài đã đổi (thích, thêm bình luận) để danh sách
  /// phía sau không hiện số cũ khi người dùng quay ra.
  final ValueChanged<DiscussionPost>? onChanged;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final _repo = DiscussionsRepository(ApiClient());
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late DiscussionPost _post = widget.post;
  List<DiscussionComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  bool _anonymous = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.comments(_post.id);
      if (mounted) {
        setState(() {
          _comments = list;
          _loading = false;
        });
      }
    } on ApiException {
      // Bình luận xem trước đã có sẵn trong feed, nên hỏng phần này vẫn còn
      // thứ để hiện thay vì một màn trắng.
      if (mounted) {
        setState(() {
          _comments = _post.previewComments;
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (widget.isGuest) return widget.onSignIn();

    final before = _post;
    setState(() => _post = _post.copyWith(
          hasLiked: !_post.hasLiked,
          likes: _post.likes + (_post.hasLiked ? -1 : 1),
        ));
    widget.onChanged?.call(_post);

    try {
      final (liked, count) = await _repo.toggleLike(_post.id);
      if (!mounted) return;
      setState(() => _post = _post.copyWith(hasLiked: liked, likes: count));
      widget.onChanged?.call(_post);
    } on ApiException {
      if (!mounted) return;
      setState(() => _post = before);
      widget.onChanged?.call(before);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (widget.isGuest) return widget.onSignIn();

    setState(() => _sending = true);
    try {
      final added =
          await _repo.addComment(_post.id, text, anonymous: _anonymous);
      if (!mounted) return;
      _input.clear();
      setState(() {
        _comments = [..._comments, added];
        _post = _post.copyWith(comments: _post.comments + 1);
        _sending = false;
      });
      widget.onChanged?.call(_post);

      // Cuộn xuống bình luận vừa gửi. Không làm thì nó nằm ngoài màn hình và
      // người dùng tưởng gửi hụt.
      await Future.delayed(const Duration(milliseconds: 60));
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      final c = Np.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: c.danger,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
        content: Text(e.message,
            style: NpType.body.copyWith(fontSize: 14, color: Colors.white)),
      ));
    }
  }

  Future<void> _vote(String optionId) async {
    try {
      final poll = await _repo.vote(_post.id, optionId);
      if (mounted && poll != null) {
        setState(() => _post = _post.copyWith(poll: poll));
        widget.onChanged?.call(_post);
      }
    } on ApiException catch (e) {
      // Giữ nguyên trạng thái cũ là đúng, nhưng IM LẶNG thì không: người dùng
      // vừa bấm một lựa chọn và không có gì xảy ra, không lời giải thích nào.
      // Với họ đó là một cái nút hỏng.
      if (!mounted) return;
      final c = Np.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: c.danger,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
        content: Text(e.message,
            style: NpType.body.copyWith(fontSize: 14, color: Colors.white)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text(_post.topicName.isEmpty ? 'Bài viết' : _post.topicName,
            style: NpType.h1.copyWith(fontSize: 19, color: c.ink)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                  Np.gutter, Np.s2, Np.gutter, Np.s6),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Avatar(
                        name: _post.authorName,
                        url: _post.authorAvatarUrl,
                        size: 42),
                    const SizedBox(width: Np.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuthorLine(post: _post),
                          if (_post.authorRole.isNotEmpty)
                            Text(_post.authorRole,
                                style: NpType.meta
                                    .copyWith(fontSize: 12, color: c.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: Np.s4),
                Text(_post.content,
                    style: NpType.body.copyWith(color: c.ink, height: 1.5)),

                if (_post.poll != null) ...[
                  const SizedBox(height: Np.s5),
                  PollBox(
                      poll: _post.poll!,
                      onVote: widget.isGuest ? null : _vote),
                ],

                const SizedBox(height: Np.s4),
                Row(
                  children: [
                    PostAction(
                      icon: _post.hasLiked ? NpIcon.heartFill : NpIcon.heart,
                      count: _post.likes,
                      active: _post.hasLiked,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: Np.s5),
                    PostAction(icon: NpIcon.chat, count: _post.comments),
                  ],
                ),

                const SizedBox(height: Np.s5),
                Divider(color: c.line, height: 1),
                const SizedBox(height: Np.s5),

                if (_loading)
                  Text('Đang tải bình luận…',
                      style: NpType.meta.copyWith(color: c.muted))
                else if (_comments.isEmpty)
                  Text('Chưa có bình luận. Bạn nói gì đó đi.',
                      style: NpType.meta.copyWith(color: c.muted))
                else
                  for (final cm in _comments) ...[
                    _CommentRow(comment: cm),
                    const SizedBox(height: Np.s4),
                  ],
              ],
            ),
          ),
          _Composer(
            controller: _input,
            sending: _sending,
            isGuest: widget.isGuest,
            onSend: _send,
            onSignIn: widget.onSignIn,
            anonymous: _anonymous,
            onToggleAnonymous: () =>
                setState(() => _anonymous = !_anonymous),
          ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});
  final DiscussionComment comment;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(name: comment.author, url: comment.avatarUrl, size: 30),
        const SizedBox(width: Np.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(comment.author,
                        style: NpType.body.copyWith(
                          fontSize: 13.5,
                          color: c.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (comment.isAnonymous) ...[
                    const SizedBox(width: Np.s1 + 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Np.rPill),
                        border: Border.all(color: c.line),
                      ),
                      child: Text('Ẩn danh',
                          style: NpType.meta.copyWith(fontSize: 9.5, color: c.muted, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (comment.createdAt != null) ...[
                    const SizedBox(width: Np.s2),
                    Text('· ${relativeTime(comment.createdAt)}',
                        style: NpType.meta
                            .copyWith(fontSize: 11.5, color: c.faint)),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(comment.content,
                  style: NpType.body.copyWith(
                      fontSize: 14, color: c.ink, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ô nhập bình luận, dính đáy.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.isGuest,
    required this.onSend,
    required this.onSignIn,
    required this.anonymous,
    required this.onToggleAnonymous,
  });

  final TextEditingController controller;
  final bool sending;
  final bool isGuest;
  final VoidCallback onSend;
  final VoidCallback onSignIn;
  final bool anonymous;
  final VoidCallback onToggleAnonymous;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    if (isGuest) {
      return Container(
        padding: EdgeInsets.fromLTRB(Np.gutter, Np.s3, Np.gutter,
            Np.s3 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: AcidButton(label: 'Đăng nhập để bình luận', onTap: onSignIn),
      );
    }

    return Container(
      // viewInsets chứ không phải padding: đây là chiều cao BÀN PHÍM. Thiếu nó
      // thì bàn phím che mất chính ô đang gõ.
      padding: EdgeInsets.fromLTRB(
        Np.gutter,
        Np.s3,
        Np.gutter,
        Np.s3 +
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Công tắc ẩn danh đặt NGAY TRÊN ô nhập, không giấu sau menu: người
          // ta quyết định có ẩn danh hay không TRƯỚC khi gõ, không phải sau.
          GestureDetector(
            onTap: onToggleAnonymous,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Np.s2, left: Np.s1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NpIco(anonymous ? NpIcon.check : NpIcon.person,
                      size: 14, color: anonymous ? c.acidText : c.faint),
                  const SizedBox(width: Np.s1 + 2),
                  Text(
                    anonymous
                        ? 'Đang bình luận ẩn danh'
                        : 'Bình luận ẩn danh',
                    style: NpType.meta.copyWith(
                      fontSize: 12,
                      color: anonymous ? c.acidText : c.faint,
                      fontWeight:
                          anonymous ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              style: NpType.body.copyWith(color: c.ink),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: Np.s4, vertical: Np.s3),
                hintText: 'Viết bình luận…',
                hintStyle: NpType.body.copyWith(color: c.faint),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Np.rLg),
                  borderSide: BorderSide(color: c.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Np.rLg),
                  borderSide: BorderSide(color: c.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Np.rLg),
                  borderSide: BorderSide(color: c.acid),
                ),
              ),
            ),
          ),
          const SizedBox(width: Np.s2),
          GestureDetector(
            onTap: sending ? null : onSend,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sending ? c.surface : c.acid,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.muted),
                    )
                  : NpIco(NpIcon.send, size: 18, color: c.onAcid),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}
