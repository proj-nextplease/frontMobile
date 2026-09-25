import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'discussion_models.dart';
import 'discussions_repository.dart';

/// Soạn bài mới.
///
/// Bảng discussion_posts không có cột tiêu đề, nên ô nhập ở đây cũng KHÔNG có
/// trường tiêu đề riêng — thêm vào thì phải nhét nó vào content bằng một quy
/// ước ngầm, và mọi nơi đọc lại đều phải biết quy ước đó. Thay vào đó gợi ý
/// người viết đặt câu đầu cho gọn, vì giao diện lấy đúng dòng đầu làm tiêu đề.
class ComposePostPage extends StatefulWidget {
  const ComposePostPage({super.key, required this.topics, this.initialTopic});

  final List<DiscussionTopic> topics;
  final String? initialTopic;

  @override
  State<ComposePostPage> createState() => _ComposePostPageState();
}

class _ComposePostPageState extends State<ComposePostPage> {
  late final _repo = DiscussionsRepository(ApiClient());
  final _content = TextEditingController();

  /// Tối đa 6 lựa chọn — giới hạn lấy từ MAX_POLL_OPTIONS phía backend.
  final _options = <TextEditingController>[];

  String? _topicSlug;
  bool _poll = false;
  bool _anonymous = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _topicSlug = widget.initialTopic ??
        (widget.topics.isEmpty ? null : widget.topics.first.slug);
    _content.addListener(_sync);
  }

  @override
  void dispose() {
    _content.removeListener(_sync);
    _content.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _sync() => setState(() {});

  void _togglePoll() {
    setState(() {
      _poll = !_poll;
      if (_poll && _options.isEmpty) {
        // Hai ô ngay từ đầu: khảo sát một lựa chọn là vô nghĩa, và backend
        // cũng từ chối (normalizePollOptions cần ít nhất hai).
        _options.addAll([TextEditingController(), TextEditingController()]);
      }
    });
  }

  List<String> get _pollValues => _options
      .map((e) => e.text.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  bool get _canSend =>
      !_sending &&
      _topicSlug != null &&
      _content.text.trim().isNotEmpty &&
      (!_poll || _pollValues.length >= 2);

  Future<void> _submit() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    try {
      await _repo.createPost(
        topicSlug: _topicSlug!,
        content: _content.text.trim(),
        pollOptions: _poll ? _pollValues : null,
        anonymous: _anonymous,
      );
      if (mounted) Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Bài mới', style: NpType.h1.copyWith(color: c.ink)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Np.gutter),
            child: GestureDetector(
              onTap: _canSend ? _submit : null,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Text(_sending ? 'Đang đăng…' : 'Đăng',
                    style: NpType.button.copyWith(
                      fontSize: 15,
                      // Tắt thì XÁM chứ không ẩn: nút biến mất khiến người
                      // dùng đi tìm và tưởng màn hình hỏng.
                      color: _canSend ? c.acidText : c.faint,
                    )),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Np.gutter, Np.s2, Np.gutter,
            Np.s6 + MediaQuery.viewInsetsOf(context).bottom),
        children: [
          const SectionLabel('Chủ đề'),
          const SizedBox(height: Np.s3),
          Wrap(
            spacing: Np.s2,
            runSpacing: Np.s2,
            children: [
              for (final t in widget.topics)
                GestureDetector(
                  onTap: () => setState(() => _topicSlug = t.slug),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Np.s4, vertical: Np.s2 + 2),
                    decoration: BoxDecoration(
                      color: _topicSlug == t.slug
                          ? c.acid.withValues(alpha: 0.16)
                          : c.surface,
                      borderRadius: BorderRadius.circular(Np.rPill),
                      border: Border.all(
                        color: _topicSlug == t.slug
                            ? c.acid.withValues(alpha: 0.55)
                            : c.line,
                      ),
                    ),
                    child: Text(t.name,
                        style: NpType.meta.copyWith(
                          fontSize: 13.5,
                          color: _topicSlug == t.slug ? c.acidText : c.ink,
                          fontWeight: _topicSlug == t.slug
                              ? FontWeight.w700
                              : FontWeight.w500,
                        )),
                  ),
                ),
            ],
          ),

          const SizedBox(height: Np.s6),
          const SectionLabel('Nội dung'),
          const SizedBox(height: Np.s3),
          TextField(
            controller: _content,
            minLines: 6,
            maxLines: 14,
            maxLength: 5000,
            autofocus: true,
            style: NpType.body.copyWith(color: c.ink, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Câu đầu tiên sẽ hiện như tiêu đề, nên viết gọn thôi.\n'
                  'Xuống dòng rồi kể chi tiết bên dưới.',
              hintStyle: NpType.body.copyWith(color: c.faint, height: 1.5),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.all(Np.s4),
              counterStyle: NpType.meta.copyWith(fontSize: 11, color: c.faint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Np.rMd),
                borderSide: BorderSide(color: c.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Np.rMd),
                borderSide: BorderSide(color: c.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Np.rMd),
                borderSide: BorderSide(color: c.acid),
              ),
            ),
          ),

          const SizedBox(height: Np.s4),
          GestureDetector(
            onTap: _togglePoll,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                NpIco(NpIcon.bolt,
                    size: 17, color: _poll ? c.acidText : c.muted),
                const SizedBox(width: Np.s2),
                Text(_poll ? 'Bỏ khảo sát' : 'Thêm khảo sát',
                    style: NpType.meta.copyWith(
                      color: _poll ? c.acidText : c.muted,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),

          const SizedBox(height: Np.s4),
          GestureDetector(
            onTap: () => setState(() => _anonymous = !_anonymous),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                NpIco(_anonymous ? NpIcon.check : NpIcon.person,
                    size: 17, color: _anonymous ? c.acidText : c.muted),
                const SizedBox(width: Np.s2),
                Text('Đăng ẩn danh',
                    style: NpType.meta.copyWith(
                      color: _anonymous ? c.acidText : c.muted,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),

          // Nói rõ giới hạn của "ẩn danh" NGAY tại chỗ bật nó.
          //
          // Tên bị ẩn với người dùng khác, nhưng hệ thống vẫn lưu ai viết —
          // nếu không thì không xử lý được quấy rối, và "ẩn danh" sẽ thành lá
          // chắn cho đúng thứ nó dễ bị lợi dụng nhất. Hứa "hoàn toàn ẩn danh"
          // rồi vẫn lưu danh tính là nói dối về quyền riêng tư, thứ người dùng
          // không có cách nào tự kiểm chứng.
          if (_anonymous) ...[
            const SizedBox(height: Np.s2),
            Text(
              'Tên và ảnh của bạn được ẩn với người dùng khác. Quản trị viên '
              'vẫn xem được để xử lý vi phạm.',
              style: NpType.meta.copyWith(
                  fontSize: 12, color: c.muted, height: 1.4),
            ),
          ],

          if (_poll) ...[
            const SizedBox(height: Np.s4),
            for (var i = 0; i < _options.length; i++) ...[
              TextField(
                controller: _options[i],
                maxLength: 100,
                style: NpType.body.copyWith(color: c.ink),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: Np.s4, vertical: Np.s3),
                  hintText: 'Lựa chọn ${i + 1}',
                  hintStyle: NpType.body.copyWith(color: c.faint),
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Np.rSm),
                    borderSide: BorderSide(color: c.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Np.rSm),
                    borderSide: BorderSide(color: c.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Np.rSm),
                    borderSide: BorderSide(color: c.acid),
                  ),
                ),
                onChanged: (_) => _sync(),
              ),
              const SizedBox(height: Np.s2),
            ],
            if (_options.length < 6)
              GestureDetector(
                onTap: () =>
                    setState(() => _options.add(TextEditingController())),
                behavior: HitTestBehavior.opaque,
                child: Text('+ Thêm lựa chọn',
                    style: NpType.meta.copyWith(
                        color: c.acidText, fontWeight: FontWeight.w600)),
              ),
          ],
        ],
      ),
    );
  }
}
