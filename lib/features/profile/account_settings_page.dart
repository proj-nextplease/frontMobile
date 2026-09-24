import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/design.dart';
import '../../core/widgets.dart';

/// Cài đặt tài khoản: thông báo, đăng xuất mọi thiết bị, vô hiệu hoá.
///
/// Ba endpoint này đã có ở backend từ lâu và web đã dùng; app thì chưa dùng
/// cái nào. Hệ quả là người chỉ dùng app KHÔNG tắt được email thông báo, và
/// mất điện thoại thì không đăng xuất từ xa được.
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, required this.onSignedOut});

  /// Gọi khi phiên hiện tại đã bị thu hồi phía máy chủ — cả "đăng xuất mọi
  /// thiết bị" lẫn "vô hiệu hoá" đều thu hồi luôn phiên của chính máy này,
  /// nên ở lại màn hình cũ là ở lại với một token đã chết.
  final Future<void> Function() onSignedOut;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _api = ApiClient();

  bool _loading = true;
  String? _loadError;

  String? _email;
  bool _emailEnabled = true;
  bool _inAppEnabled = true;

  /// Đọc lên rồi gửi trả nguyên vẹn. Không hiện thành công tắc vì backend
  /// LƯU nó mà không bao giờ ĐỌC — chỉ email_enabled và in_app_enabled mới
  /// thật sự chặn thông báo. Một công tắc không điều khiển gì là lời nói dối
  /// nhỏ mà người dùng không có cách nào phát hiện.
  bool _pushEnabled = false;

  bool _savingPrefs = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await _api.get('/account/me');
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          _email = data['email'] as String?;
          _emailEnabled = data['emailNotificationsEnabled'] != false;
          _inAppEnabled = data['inAppNotificationsEnabled'] != false;
          _pushEnabled = data['pushNotificationsEnabled'] == true;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _savePrefs({bool? email, bool? inApp}) async {
    final prevEmail = _emailEnabled;
    final prevInApp = _inAppEnabled;

    setState(() {
      if (email != null) _emailEnabled = email;
      if (inApp != null) _inAppEnabled = inApp;
      _savingPrefs = true;
    });

    try {
      // Gửi CẢ BA trường. Bỏ pushEnabled thì nó bị ghi thành false — cùng
      // cái bẫy với openToWork ở màn hồ sơ công khai.
      await _api.put('/account/notification-preferences', body: {
        'emailEnabled': _emailEnabled,
        'pushEnabled': _pushEnabled,
        'inAppEnabled': _inAppEnabled,
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _emailEnabled = prevEmail;
        _inAppEnabled = prevInApp;
      });
      _toast(e.message, ok: false);
    }
    if (mounted) setState(() => _savingPrefs = false);
  }

  Future<void> _signOutAll() async {
    final ok = await _confirm(
      title: 'Đăng xuất mọi thiết bị?',
      body: 'Mọi phiên đăng nhập sẽ bị thu hồi, kể cả trên máy này — bạn sẽ '
          'phải đăng nhập lại.',
      action: 'Đăng xuất',
    );
    if (ok != true) return;

    try {
      await _api.post('/account/sign-out-all-sessions');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message, ok: false);
      return;
    }
    await widget.onSignedOut();
  }

  Future<void> _deactivate() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (password == null || password.isEmpty) return;

    try {
      await _api.post('/account/deactivate', body: {'password': password});
    } on ApiException catch (e) {
      if (mounted) _toast(e.message, ok: false);
      return;
    }
    await widget.onSignedOut();
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) {
    final c = Np.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rLg)),
        title: Text(title, style: NpType.title.copyWith(color: c.ink)),
        content: Text(body, style: NpType.body.copyWith(color: c.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Huỷ', style: NpType.button.copyWith(color: c.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action,
                style: NpType.button
                    .copyWith(color: danger ? c.danger : c.acidText)),
          ),
        ],
      ),
    );
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

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Cài đặt tài khoản',
            style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.faint))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  Np.gutter, Np.s2, Np.gutter, Np.navInset),
              children: [
                if (_loadError != null) ...[
                  _ErrorCard(message: _loadError!, onRetry: _load),
                  const SizedBox(height: Np.s5),
                ],

                if (_email != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Np.s4),
                    decoration: Np.card(c, hi: true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ĐANG ĐĂNG NHẬP',
                            style: NpType.label.copyWith(color: c.muted)),
                        const SizedBox(height: Np.s2),
                        Text(_email!,
                            style: NpType.body.copyWith(
                                color: c.ink, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: Np.s6),
                ],

                const SectionLabel('Thông báo'),
                const SizedBox(height: Np.s3),
                _SwitchRow(
                  title: 'Thông báo trong ứng dụng',
                  hint: 'Chuông và banner khi có đơn, bình luận, nhiệm vụ mới. '
                      'Tắt thì chuông sẽ im hoàn toàn.',
                  value: _inAppEnabled,
                  busy: _savingPrefs,
                  onChanged: (v) => _savePrefs(inApp: v),
                ),
                const SizedBox(height: Np.s2),
                _SwitchRow(
                  title: 'Gửi email cho tôi',
                  hint: 'Chỉ dùng cho vài loại quan trọng, không phải mọi '
                      'thông báo.',
                  value: _emailEnabled,
                  busy: _savingPrefs,
                  onChanged: (v) => _savePrefs(email: v),
                ),

                const SizedBox(height: Np.s6),
                const SectionLabel('Bảo mật'),
                const SizedBox(height: Np.s3),
                _ActionRow(
                  title: 'Đăng xuất khỏi mọi thiết bị',
                  hint: 'Dùng khi bạn mất máy hoặc lỡ đăng nhập ở máy lạ.',
                  onTap: _signOutAll,
                ),

                const SizedBox(height: Np.s8),
                const SectionLabel('Vùng nguy hiểm'),
                const SizedBox(height: Np.s3),
                _ActionRow(
                  title: 'Vô hiệu hoá tài khoản',
                  hint: 'Hồ sơ bị ẩn và bạn không đăng nhập được nữa. Dữ liệu '
                      'không bị xoá — liên hệ hỗ trợ nếu muốn mở lại.',
                  danger: true,
                  onTap: _deactivate,
                ),
              ],
            ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.hint,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: NpType.body.copyWith(
                        color: c.ink, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(hint, style: NpType.meta.copyWith(color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: Np.s3),
          Switch(
            value: value,
            activeThumbColor: c.onAcid,
            activeTrackColor: c.acid,
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.hint,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final String hint;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Np.s4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Np.rLg),
          border: Border.all(
              color: danger ? c.danger.withValues(alpha: 0.4) : c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: NpType.body.copyWith(
                    color: danger ? c.danger : c.ink,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(hint, style: NpType.meta.copyWith(color: c.muted)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Np.s4),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Np.rMd),
        border: Border.all(color: c.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Không tải được cài đặt.',
              style: NpType.body.copyWith(
                  color: c.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(message, style: NpType.meta.copyWith(color: c.muted)),
          const SizedBox(height: Np.s3),
          GestureDetector(
            onTap: onRetry,
            child: Text('Thử lại',
                style: NpType.button
                    .copyWith(fontSize: 14, color: c.acidText)),
          ),
        ],
      ),
    );
  }
}

/// Xin mật khẩu để xác nhận vô hiệu hoá.
///
/// Máy chủ ĐÒI mật khẩu (AccountSettingsService.deactivateAccount gọi
/// authenticateUser trước khi đóng băng). Ô này chỉ chuyển thẳng chuỗi người
/// dùng gõ sang endpoint đó — app không lưu lại ở đâu.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final ok = _ctrl.text.isNotEmpty;

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Np.rLg)),
      title: Text('Vô hiệu hoá tài khoản',
          style: NpType.title.copyWith(color: c.ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sau khi vô hiệu hoá, bạn sẽ bị đăng xuất và không đăng nhập lại '
            'được. Nhập mật khẩu để xác nhận.',
            style: NpType.body.copyWith(color: c.muted),
          ),
          const SizedBox(height: Np.s4),
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: !_show,
            onChanged: (_) => setState(() {}),
            style: NpType.body.copyWith(color: c.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Mật khẩu',
              hintStyle: NpType.body.copyWith(color: c.faint),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _show = !_show),
                child: Icon(
                  _show ? Icons.visibility_off : Icons.visibility,
                  size: 19,
                  color: c.faint,
                ),
              ),
              enabledBorder:
                  UnderlineInputBorder(borderSide: BorderSide(color: c.line)),
              focusedBorder:
                  UnderlineInputBorder(borderSide: BorderSide(color: c.acid)),
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
          onPressed: ok ? () => Navigator.of(context).pop(_ctrl.text) : null,
          child: Text('Vô hiệu hoá',
              style: NpType.button
                  .copyWith(color: ok ? c.danger : c.faint)),
        ),
      ],
    );
  }
}
