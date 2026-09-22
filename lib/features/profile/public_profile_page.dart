import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/design.dart';
import '../../core/np_icons.dart';
import '../../core/widgets.dart';
import 'me_store.dart';

/// Hồ sơ công khai: đường dẫn chia sẻ, công tắc bật/tắt, và đổi đường dẫn.
///
/// Trang hồ sơ công khai sống trên WEB (`/p/<slug>`), không dựng lại trong app.
/// Dựng lại là tạo bản thứ hai của cùng một trang và chúng sẽ lệch nhau; thứ
/// người dùng cần ở đây là cái LINK để gửi cho nhà tuyển dụng.
class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({super.key});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final _api = ApiClient();
  final _me = MeStore.instance;

  bool? _isPublic;
  bool _openToWork = false;
  bool _savingPrivacy = false;

  @override
  void initState() {
    super.initState();
    _me.addListener(_sync);
    _loadSettings();
  }

  @override
  void dispose() {
    _me.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  String? get _slug => _me.publicSlug;
  String get _url => '${AppConfig.webBaseUrl}/p/${_slug ?? ''}';

  Future<void> _loadSettings() async {
    try {
      final data = await _api.get('/account/me');
      if (mounted && data is Map) {
        setState(() {
          _isPublic = data['isPublic'] != false;
          _openToWork = data['openToWork'] == true;
        });
      }
    } on ApiException {
      // Không biết trạng thái thì để công tắc ở dạng chưa xác định thay vì
      // đoán bừa "đang bật" — đoán sai ở đây nghĩa là nói với người dùng rằng
      // hồ sơ của họ đang công khai trong khi nó không.
    }
  }

  Future<void> _togglePublic(bool value) async {
    setState(() {
      _isPublic = value;
      _savingPrivacy = true;
    });

    try {
      // PUT nhận CẢ HAI trường. Gửi thiếu openToWork thì nó bị ghi đè thành
      // false, và người dùng lặng lẽ biến mất khỏi danh sách đang tìm việc.
      await _api.put('/account/privacy',
          body: {'isPublic': value, 'openToWork': _openToWork});
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isPublic = !value);
      _toast(e.message, ok: false);
    }
    if (mounted) setState(() => _savingPrivacy = false);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (mounted) _toast('Đã chép đường dẫn.', ok: true);
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(_url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _editSlug() async {
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _SlugDialog(current: _slug ?? ''),
    );
    if (next == null || !mounted) return;

    try {
      await _api.patch('/profiles/me/slug', body: {'slug': next});
      await _me.hydrate();
      if (mounted) _toast('Đã đổi đường dẫn.', ok: true);
    } on ApiException catch (e) {
      // Trùng tên chỉ máy chủ mới biết, nên thông báo của nó là thông báo
      // đúng — không thay bằng câu chung chung của mình.
      if (mounted) _toast(e.message, ok: false);
    }
  }

  void _toast(String msg, {required bool ok}) {
    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? c.surfaceHi : c.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
      content: Text(msg,
          style: NpType.body
              .copyWith(fontSize: 14, color: ok ? c.ink : Colors.white)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final slug = _slug;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Hồ sơ công khai',
            style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Np.gutter, Np.s2, Np.gutter, Np.navInset),
        children: [
          Text(
            'Một trang web hiển thị kỹ năng, kinh nghiệm và minh chứng đã '
            'được duyệt của bạn. Gửi link này thay cho CV.',
            style: NpType.body.copyWith(color: c.muted),
          ),
          const SizedBox(height: Np.s5),

          if (slug == null)
            _Note('Đang tải đường dẫn…')
          else ...[
            Container(
              padding: const EdgeInsets.all(Np.s4),
              decoration: Np.card(c, hi: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ĐƯỜNG DẪN CỦA BẠN',
                      style: NpType.label.copyWith(color: c.muted)),
                  const SizedBox(height: Np.s2),
                  SelectableText(_url,
                      style: NpType.body.copyWith(
                          color: c.ink, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: Np.s3),
            Row(
              children: [
                Expanded(
                  child: _Action(
                      icon: NpIcon.send, label: 'Chép link', onTap: _copy),
                ),
                const SizedBox(width: Np.s2),
                Expanded(
                  child: _Action(
                      icon: NpIcon.arrow, label: 'Xem thử', onTap: _open),
                ),
                const SizedBox(width: Np.s2),
                Expanded(
                  child: _Action(
                      icon: NpIcon.person,
                      label: 'Đổi tên',
                      onTap: _editSlug),
                ),
              ],
            ),
          ],

          const SizedBox(height: Np.s6),
          const SectionLabel('Ai xem được'),
          const SizedBox(height: Np.s3),

          Container(
            padding: const EdgeInsets.all(Np.s4),
            decoration: Np.card(c),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cho phép người ngoài xem',
                          style: NpType.body.copyWith(
                              color: c.ink, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(_privacyHint(),
                          style: NpType.meta.copyWith(color: c.muted)),
                    ],
                  ),
                ),
                if (_isPublic == null)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.faint),
                  )
                else
                  Switch(
                    value: _isPublic!,
                    activeThumbColor: c.onAcid,
                    activeTrackColor: c.acid,
                    onChanged: _savingPrivacy ? null : _togglePublic,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nói rõ điều gì xảy ra ở mỗi trạng thái, kể cả phần người dùng dễ hiểu
  /// nhầm: tắt KHÔNG giấu hồ sơ khỏi nơi bạn đã ứng tuyển.
  String _privacyHint() => switch (_isPublic) {
        null => 'Đang kiểm tra…',
        true => 'Bất kỳ ai có link đều mở được.',
        _ => 'Chỉ bạn và nơi bạn đã ứng tuyển xem được.',
      };
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final NpIcon icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Np.s3),
        decoration: Np.card(c, radius: Np.rMd),
        child: Column(
          children: [
            NpIco(icon, size: 18, color: c.ink),
            const SizedBox(height: Np.s1),
            Text(label,
                style: NpType.meta.copyWith(
                    color: c.ink, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: Np.s6),
      decoration: Np.card(c),
      child: Text(text,
          textAlign: TextAlign.center,
          style: NpType.meta.copyWith(color: c.muted)),
    );
  }
}

/// Đổi phần đuôi của đường dẫn.
class _SlugDialog extends StatefulWidget {
  const _SlugDialog({required this.current});
  final String current;

  @override
  State<_SlugDialog> createState() => _SlugDialogState();
}

class _SlugDialogState extends State<_SlugDialog> {
  late final _ctrl = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Kiểm ngay tại máy để người dùng biết sai trước khi bấm.
  ///
  /// Đây là BẢN SAO của luật phía máy chủ (Slugs.java) và chỉ để phản hồi
  /// nhanh — máy chủ vẫn là nơi quyết định, nhất là chuyện trùng tên, thứ mà
  /// máy không thể tự biết.
  String? get _error {
    final s = _ctrl.text.trim().toLowerCase();
    if (s.isEmpty) return 'Vui lòng nhập đường dẫn.';
    if (s.length < 3) return 'Phải có ít nhất 3 ký tự.';
    if (s.length > 40) return 'Tối đa 40 ký tự.';
    if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(s)) {
      return 'Chỉ gồm chữ thường không dấu, số và dấu gạch ngang; không bắt '
          'đầu, kết thúc hay lặp dấu gạch ngang.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final err = _error;

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Np.rLg)),
      title: Text('Đổi đường dẫn', style: NpType.title.copyWith(color: c.ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${AppConfig.webBaseUrl}/p/',
              style: NpType.meta.copyWith(color: c.muted)),
          const SizedBox(height: Np.s2),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: NpType.body.copyWith(color: c.ink),
            decoration: InputDecoration(
              isDense: true,
              errorText: _ctrl.text.trim().isEmpty ? null : err,
              errorStyle: NpType.meta.copyWith(color: c.danger),
              // Mặc định errorText chỉ một dòng, và luật đặt đường dẫn dài
              // hơn thế — người dùng đọc được "Chỉ gồm chữ thường không dấu,
              // số …" rồi hết, tức là biết mình sai mà không biết sai gì.
              errorMaxLines: 4,
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: c.line)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: c.acid)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Huỷ', style: NpType.button.copyWith(color: c.muted)),
        ),
        TextButton(
          onPressed: err != null
              ? null
              : () => Navigator.of(context).pop(_ctrl.text.trim().toLowerCase()),
          child: Text('Lưu',
              style: NpType.button
                  .copyWith(color: err != null ? c.faint : c.acidText)),
        ),
      ],
    );
  }
}
