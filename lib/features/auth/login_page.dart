import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/paper_theme.dart';
import 'social_mark.dart';

/// Nhà cung cấp đăng nhập mạng xã hội.
///
/// Đúng ba cái web đang bật ở Supabase. Thêm cái thứ tư ở đây mà chưa bật bên
/// Dashboard thì nút bấm vào sẽ lỗi.
enum SocialProvider { google, facebook, github }

extension SocialProviderX on SocialProvider {
  String get label => switch (this) {
        SocialProvider.google => 'Google',
        SocialProvider.facebook => 'Facebook',
        SocialProvider.github => 'GitHub',
      };
}

/// Màn hình đăng nhập — hệ GIẤY/STICKER (xem DESIGN.md).
///
/// "Loud ở vỏ, calm ở ruột": phần chào và sticker được phép ồn ào, còn ô nhập
/// giữ đúng tương phản của một biểu mẫu gõ được.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onEmailLogin,
    required this.onSocialLogin,
    required this.onSkip,
  });

  final Future<String?> Function(String email, String password) onEmailLogin;
  final Future<String?> Function(SocialProvider provider) onSocialLogin;

  /// Web để /jobs công khai, nên chặn đăng nhập ngay màn hình đầu sẽ chặt hơn
  /// web một cách vô lý — và là cách nhanh nhất để người dùng mới gỡ app.
  final VoidCallback onSkip;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Bóng cứng chỉ hiện ở ô ĐANG gõ, nên phải vẽ lại khi tiêu điểm đổi.
    _emailFocus.addListener(_redraw);
    _passwordFocus.addListener(_redraw);
  }

  void _redraw() => setState(() {});

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    /* Thanh trạng thái: màn hình này nền SÁNG trong khi phần còn lại của app
       là nền tối, nên nếu không ép kiểu thì giờ và pin vẫn vẽ màu trắng — gần
       như vô hình trên nền giấy. AnnotatedRegion đặt lại chỉ cho màn hình này
       và tự trả về cũ khi rời đi.

       Hai bộ thuộc tính vì iOS và Android đọc hai trường khác nhau: iOS dùng
       statusBarBrightness, Android dùng statusBarIconBrightness, và ý nghĩa
       của chúng NGƯỢC nhau — iOS mô tả nền, Android mô tả icon. */
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,       // iOS: nền sáng → chữ đen
        statusBarIconBrightness: Brightness.dark,    // Android: icon tối
      ),
      child: Scaffold(
      backgroundColor: Paper.bg,
      body: SafeArea(
        child: ListView(
          // Đệm đáy cộng thêm chiều cao bàn phím: không có nó thì bàn phím che
          // mất nút Đăng nhập và người dùng phải tự cuộn.
          padding: EdgeInsets.fromLTRB(
            22, 8, 22, 28 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            const _Hero(),
            const SizedBox(height: 26),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _Field(
                    controller: _email,
                    focusNode: _emailFocus,
                    label: 'EMAIL',
                    hint: 'ban@truong.edu.vn',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Chưa nhập email';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    controller: _password,
                    focusNode: _passwordFocus,
                    label: 'MẬT KHẨU',
                    hint: '••••••••',
                    obscure: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Chưa nhập mật khẩu' : null,
                    trailing: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14, left: 6),
                        child: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Paper.ink,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _forgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: Paper.ink,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    decoration: TextDecoration.underline,
                    decorationThickness: 2,
                  ),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 6),
              _ErrorNote(message: _error!),
            ],

            const SizedBox(height: 18),
            _BigButton(
              label: 'ĐĂNG NHẬP',
              fill: Paper.lime,
              busy: _busy,
              onTap: _submit,
            ),

            const SizedBox(height: 26),
            const _OrRow(),
            const SizedBox(height: 18),

            // Hàng ngang ba ô vuông thay vì ba nút dọc: bản trước ăn gần nửa
            // màn hình cho thứ đa số người chỉ bấm một cái.
            Row(
              children: [
                for (final p in SocialProvider.values) ...[
                  Expanded(
                    child: _SocialTile(
                      provider: p,
                      enabled: !_busy,
                      onTap: () => _run(() => widget.onSocialLogin(p)),
                    ),
                  ),
                  if (p != SocialProvider.values.last) const SizedBox(width: 12),
                ],
              ],
            ),

            const SizedBox(height: 28),
            _SignUpRow(onTap: _busy ? null : _goRegister),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _busy ? null : widget.onSkip,
                style: TextButton.styleFrom(foregroundColor: Paper.ink),
                child: const Text(
                  'Xem cơ hội trước đã  →',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    _run(() => widget.onEmailLogin(_email.text.trim(), _password.text));
  }

  // Hai luồng này chưa dựng. Nói thẳng ra thay vì để nút bấm vào không có gì
  // xảy ra — người dùng sẽ tưởng app hỏng.
  void _forgotPassword() => _notYet('Đặt lại mật khẩu');
  void _goRegister() => _notYet('Đăng ký tài khoản');

  void _notYet(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Paper.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          '$what chưa có trong app. Tạm thời dùng trên website nhé.',
          style: const TextStyle(color: Paper.bg, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Phần chào: sticker xoay + tên khổng lồ. Đây là chỗ được phép ồn ào.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Chỉ sticker được xoay, không bao giờ xoay thứ nhận thao tác nhập.
              Transform.rotate(
                angle: -0.06,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: Paper.card(fill: Paper.coral, radius: 999, dx: 3, dy: 3),
                  child: const Text(
                    'CHÀO BẠN',
                    style: TextStyle(
                      color: Paper.bg,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.6,
                      height: kViUppercaseLineHeight,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Transform.rotate(
                angle: 0.12,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: Paper.card(fill: Paper.violet, radius: 10, dx: 3, dy: 3),
                  child: const Text('✦',
                      style: TextStyle(color: Paper.bg, fontSize: 17)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Việc xịn\ncho sinh viên.',
            style: TextStyle(
              color: Paper.ink,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.02,
              letterSpacing: -1.6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Paper.lime,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Paper.ink, width: 1.5),
                ),
                child: const Text(
                  'nextplease:',
                  style: TextStyle(
                    color: Paper.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'hồ sơ dựa trên bằng chứng',
                  style: TextStyle(color: Paper.ink, fontSize: 14, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Paper.ink,
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
            letterSpacing: 1,
            height: kViUppercaseLineHeight,
          ),
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: Paper.field(focused: focusNode.hasFocus),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onFieldSubmitted: onSubmitted,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: Paper.ink,
            style: const TextStyle(
              color: Paper.ink,
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Paper.ink.withValues(alpha: 0.38),
                fontWeight: FontWeight.w500,
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              suffixIcon: trailing,
              suffixIconConstraints: const BoxConstraints(minWidth: 0),
              // Lỗi hiện dưới khung thay vì trong khung, để chiều cao ô không
              // nhảy khi lỗi xuất hiện.
              errorStyle: const TextStyle(
                color: Paper.coral,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatefulWidget {
  const _BigButton({
    required this.label,
    required this.fill,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final Color fill;
  final VoidCallback onTap;
  final bool busy;

  @override
  State<_BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<_BigButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    // Bấm xuống thì nút trượt vào đúng chỗ bóng của nó — cảm giác như một nút
    // vật lý bị ấn xuống. Đây là cách hệ sticker thể hiện trạng thái bấm, thay
    // cho gợn sóng của Material.
    final pressed = _down && !widget.busy;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        if (!widget.busy) widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        transform: Matrix4.translationValues(pressed ? 4 : 0, pressed ? 4 : 0, 0),
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Paper.ink, width: Paper.border),
          boxShadow: pressed ? null : Paper.hardShadow(dx: 4, dy: 4),
        ),
        child: widget.busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.6, color: Paper.ink),
              )
            : Text(
                widget.label,
                style: const TextStyle(
                  color: Paper.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  letterSpacing: 0.4,
                  height: kViUppercaseLineHeight,
                ),
              ),
      ),
    );
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({
    required this.provider,
    required this.onTap,
    required this.enabled,
  });

  final SocialProvider provider;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Đăng nhập bằng ${provider.label}',
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Container(
              height: 60,
              alignment: Alignment.center,
              decoration: Paper.card(radius: 14, dx: 3, dy: 3),
              child: SocialMark(provider: provider, size: 25),
            ),
          ),
        ),
      );
}

class _OrRow extends StatelessWidget {
  const _OrRow();
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider(color: Paper.ink, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'hoặc',
              style: TextStyle(
                color: Paper.ink.withValues(alpha: 0.65),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Paper.ink, thickness: 1.5)),
        ],
      );
}

class _SignUpRow extends StatelessWidget {
  const _SignUpRow({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Chưa có tài khoản? ',
              style: TextStyle(color: Paper.ink, fontSize: 15),
            ),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Paper.violet,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Paper.ink, width: 1.5),
                ),
                child: const Text(
                  'Đăng ký',
                  style: TextStyle(
                    color: Paper.bg,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: Paper.card(fill: Paper.coral, radius: 12, dx: 3, dy: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('!',
                style: TextStyle(
                    color: Paper.bg,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    height: 1.2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Paper.bg,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
