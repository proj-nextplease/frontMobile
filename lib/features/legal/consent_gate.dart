import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/design.dart';
import '../../core/widgets.dart';
import '../profile/me_store.dart';
import 'legal.dart';

/// Chặn sử dụng cho tới khi người dùng đồng ý với văn bản pháp lý hiện hành.
///
/// VÌ SAO Ở ĐÂY CHỨ KHÔNG PHẢI Ở MÀN ĐĂNG KÝ: điều kiện cần kiểm không phải
/// "đang ở màn nào" mà là "tài khoản này đã có bản ghi đồng ý chưa". Gắn ở
/// màn đăng ký thì sót hết những lối vào khác — đăng nhập bằng Google (cũng
/// tạo tài khoản mới), toàn bộ người dùng đã có từ trước, và những lần sửa
/// văn bản sau này. Web đã đi đến cùng kết luận đó (FE ConsentGuard).
///
/// Bọc NGOÀI Navigator, cùng lý do với banner thông báo: đặt trong `home:`
/// thì bất kỳ màn nào được đẩy lên cũng che mất cổng, và người dùng dùng tiếp
/// như chưa có gì.
class ConsentGate extends StatefulWidget {
  const ConsentGate({
    super.key,
    required this.child,
    required this.enabled,
    required this.onDecline,
  });

  final Widget child;

  /// Chỉ bật khi đã đăng nhập. Khách xem dạo chưa có tài khoản để ghi đồng ý.
  final bool enabled;

  /// Người dùng chọn rời đi — đăng xuất.
  final Future<void> Function() onDecline;

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  final _me = MeStore.instance;
  final _api = ApiClient();

  bool _saving = false;
  String? _error;

  /// Đã ghi nhận xong trong phiên này. Giữ riêng thay vì chỉ dựa vào MeStore:
  /// /profiles/me còn mang phiên bản cũ cho tới lần nạp sau, và nếu chỉ dựa
  /// vào nó thì cổng hiện lại ngay sau khi người dùng vừa bấm đồng ý.
  bool _justAccepted = false;

  @override
  void initState() {
    super.initState();
    _me.addListener(_sync);
  }

  @override
  void dispose() {
    _me.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  /// Chỉ chặn khi CHẮC CHẮN là thiếu đồng ý.
  ///
  /// `loaded == false` nghĩa là chưa biết gì — chặn lúc đó thì cổng nháy lên
  /// rồi biến mất ở mỗi lần mở app, kể cả với người đã đồng ý từ lâu.
  bool get _blocking {
    if (!widget.enabled || !_me.loaded || _justAccepted) return false;
    return _me.legalConsentVersion != kLegalVersion;
  }

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.post('/me/legal-consent', body: {'version': kLegalVersion});
      // Nạp lại để hồ sơ mang phiên bản mới; _justAccepted lo phần giao diện
      // trong lúc chờ.
      if (mounted) setState(() => _justAccepted = true);
      await _me.hydrate();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _saving = false);
  }

  bool? _viewingDocTerms;

  void _openDoc(bool isTerms) {
    setState(() => _viewingDocTerms = isTerms);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_blocking) ...[
          Positioned.fill(
            child: _Sheet(
              saving: _saving,
              error: _error,
              onAccept: _accept,
              onDecline: widget.onDecline,
              onOpenTerms: () => _openDoc(true),
              onOpenPrivacy: () => _openDoc(false),
            ),
          ),
          if (_viewingDocTerms != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.6),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _LegalDocumentModal(
                      initialIsTerms: _viewingDocTerms!,
                      onClose: () => setState(() => _viewingDocTerms = null),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.saving,
    required this.error,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool saving;
  final String? error;
  final VoidCallback onAccept;
  final Future<void> Function() onDecline;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Material(
      color: c.bg,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Np.gutter, Np.s8, Np.gutter, Np.s5),
                children: [
                  Text('ĐIỀU KHOẢN & QUYỀN RIÊNG TƯ',
                      style: NpType.label.copyWith(color: c.muted)),
                  const SizedBox(height: Np.s3),
                  Text('Trước khi bắt đầu',
                      style: NpType.display.copyWith(color: c.ink)),
                  const SizedBox(height: Np.s4),
                  Text(
                    'fonlio ghi nhận năng lực của bạn bằng minh chứng, nên '
                    'có vài điều cần thống nhất trước.',
                    style: NpType.body.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: Np.s6),

                  for (final p in kConsentPoints) ...[
                    _Point(title: p.title, body: p.body),
                    const SizedBox(height: Np.s3),
                  ],

                  const SizedBox(height: Np.s2),
                  Text(
                    'Đây là bản tóm tắt. Văn bản đầy đủ mới là bản có hiệu lực:',
                    style: NpType.meta.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: Np.s3),
                  Row(
                    children: [
                      _DocLink(label: 'Điều khoản dịch vụ', onTap: onOpenTerms),
                      const SizedBox(width: Np.s2),
                      _DocLink(label: 'Quyền riêng tư', onTap: onOpenPrivacy),
                    ],
                  ),
                ],
              ),
            ),

            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Np.gutter, 0, Np.gutter, Np.s3),
                child: Text(error!,
                    style: NpType.meta.copyWith(color: c.danger)),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Np.gutter, 0, Np.gutter, Np.s5),
              child: Column(
                children: [
                  AcidButton(
                    label: saving ? 'Đang ghi nhận…' : 'Tôi đồng ý',
                    busy: saving,
                    enabled: !saving,
                    onTap: onAccept,
                  ),
                  const SizedBox(height: Np.s3),
                  // Cổng đã chặn sử dụng thì không thể cho đóng rồi dùng tiếp.
                  // Hai lối ra trung thực: đồng ý, hoặc rời đi.
                  GestureDetector(
                    onTap: saving ? null : () => onDecline(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(Np.s2),
                      child: Text('Không đồng ý và đăng xuất',
                          style: NpType.meta.copyWith(color: c.muted)),
                    ),
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

class _Point extends StatelessWidget {
  const _Point({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: NpType.body
                  .copyWith(color: c.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: Np.s1),
          Text(body, style: NpType.meta.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}

class _DocLink extends StatelessWidget {
  const _DocLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Np.rPill),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: NpType.meta.copyWith(
                    color: c.acidText, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.visibility_outlined, size: 14, color: c.acidText),
          ],
        ),
      ),
    );
  }
}

class _LegalDocumentModal extends StatefulWidget {
  const _LegalDocumentModal({
    required this.initialIsTerms,
    required this.onClose,
  });
  final bool initialIsTerms;
  final VoidCallback onClose;

  @override
  State<_LegalDocumentModal> createState() => _LegalDocumentModalState();
}

class _LegalDocumentModalState extends State<_LegalDocumentModal> {
  late bool _isTerms = widget.initialIsTerms;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final doc = _isTerms ? kTermsDoc : kPrivacyDoc;

    return Material(
      color: c.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Np.rLg)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Np.rLg)),
          border: Border.all(color: c.line),
        ),
        child: Column(
        children: [
          // Drag handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s3, Np.gutter, Np.s2),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: Np.s3),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.title,
                              style: NpType.h1.copyWith(color: c.ink)),
                          const SizedBox(height: 2),
                          Text('Cập nhật: ${doc.updated}',
                              style: NpType.meta.copyWith(color: c.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: c.ink),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: Np.s3),
                // Tab switcher
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(Np.rPill),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          label: 'Điều khoản dịch vụ',
                          selected: _isTerms,
                          onTap: () => setState(() => _isTerms = true),
                        ),
                      ),
                      Expanded(
                        child: _TabButton(
                          label: 'Quyền riêng tư',
                          selected: !_isTerms,
                          onTap: () => setState(() => _isTerms = false),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable document content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s4, Np.gutter, Np.s6),
              children: [
                // Intro box
                Container(
                  padding: const EdgeInsets.all(Np.s3),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(Np.rMd),
                    border: Border.all(color: c.line),
                  ),
                  child: Text(
                    doc.intro,
                    style: NpType.body.copyWith(color: c.muted, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: Np.s4),

                // Sections
                for (final section in doc.sections) ...[
                  Text(
                    section.heading,
                    style: NpType.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Np.s2),
                  for (final p in section.paragraphs) ...[
                    Text(
                      p,
                      style: NpType.body.copyWith(color: c.muted, height: 1.5),
                    ),
                    const SizedBox(height: Np.s2),
                  ],
                  if (section.bulletPoints != null) ...[
                    for (final bullet in section.bulletPoints!) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: Np.s3, bottom: Np.s2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ',
                                style: NpType.body.copyWith(
                                    color: c.acidText, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                bullet,
                                style: NpType.body.copyWith(color: c.muted, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: Np.s4),
                ],
              ],
            ),
          ),

          // Bottom Action
          Padding(
            padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s2, Np.gutter, Np.s4),
            child: AcidButton(
              label: 'Đã đọc và hiểu',
              onTap: widget.onClose,
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: Np.s2),
        decoration: BoxDecoration(
          color: selected ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(Np.rPill),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: NpType.meta.copyWith(
            color: selected ? c.ink : c.muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

