import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
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
    // Ô đang gõ có viền tím; phải vẽ lại khi tiêu điểm đổi.
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Nền sáng nên phải ép chữ thanh trạng thái sang tối. iOS đọc
      // statusBarBrightness (mô tả NỀN), Android đọc statusBarIconBrightness
      // (mô tả ICON) — hai trường ngược nghĩa nhau.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Np.bg,
        body: Stack(
          children: [
            // Quầng gradient duy nhất, neo ở góc trên. Toàn bộ màu của màn
            // hình đến từ đây và từ nút chính — không rải ra chỗ khác.
            const _TopGlow(),
            SafeArea(
              child: ListView(
                // Đệm đáy cộng chiều cao bàn phím, nếu không bàn phím che mất
                // nút Đăng nhập.
                padding: EdgeInsets.fromLTRB(
                  Np.gutter, 12, Np.gutter,
                  28 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  const SizedBox(height: 26),
                  Text('Chào bạn 👋',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          )),
                  const SizedBox(height: 8),
                  const _Headline(),
                  const SizedBox(height: 32),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _Field(
                          controller: _email,
                          focusNode: _emailFocus,
                          hint: 'Email',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Chưa nhập email';
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(s)) {
                              return 'Email không hợp lệ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 13),
                        _Field(
                          controller: _password,
                          focusNode: _passwordFocus,
                          hint: 'Mật khẩu',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          validator: (v) =>
                              (v ?? '').isEmpty ? 'Chưa nhập mật khẩu' : null,
                          trailing: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Np.muted,
                              size: 20,
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
                        foregroundColor: Np.violet,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Quên mật khẩu?',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    _ErrorNote(message: _error!),
                    const SizedBox(height: 4),
                  ],

                  const SizedBox(height: 12),
                  GradientButton(
                    label: 'Đăng nhập',
                    busy: _busy,
                    onTap: _submit,
                    icon: Icons.arrow_forward_rounded,
                  ),

                  const SizedBox(height: 26),
                  const _OrRow(),
                  const SizedBox(height: 16),

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
                        if (p != SocialProvider.values.last)
                          const SizedBox(width: 11),
                      ],
                    ],
                  ),

                  const SizedBox(height: 26),
                  _SignUpRow(onTap: _busy ? null : _goRegister),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : widget.onSkip,
                      style: TextButton.styleFrom(foregroundColor: Np.muted),
                      child: const Text('Xem cơ hội trước đã',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14.5)),
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
        backgroundColor: Np.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Np.rSm)),
        content: Text(
          '$what chưa có trong app. Tạm thời dùng trên website nhé.',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _TopGlow extends StatelessWidget {
  const _TopGlow();
  @override
  Widget build(BuildContext context) => Positioned(
        top: -140,
        right: -90,
        child: Container(
          width: 340,
          height: 340,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Np.violet.withValues(alpha: 0.20),
                Np.pink.withValues(alpha: 0.06),
                Np.pink.withValues(alpha: 0),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
      );
}

class _Headline extends StatelessWidget {
  const _Headline();
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tìm việc xịn,',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 32,
                    letterSpacing: -1.1,
                  )),
          // Chỉ MỘT cụm được tô gradient trên mỗi màn hình. Tô nhiều chỗ thì
          // không còn chỗ nào là điểm nhấn.
          GradientText(
            'xây hồ sơ thật.',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontSize: 32,
                  letterSpacing: -1.1,
                ),
          ),
        ],
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      decoration: BoxDecoration(
        color: Np.surface,
        borderRadius: BorderRadius.circular(Np.rMd),
        // Không viền khi nghỉ — chỉ bóng mềm. Viền chỉ xuất hiện lúc đang gõ,
        // và là viền tím mảnh chứ không phải đường kẻ đen.
        border: Border.all(
          color: focused ? Np.violet : Colors.transparent,
          width: 1.6,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Np.violet.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : Np.cardShadow,
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: Np.violet,
        style: const TextStyle(
            color: Np.ink, fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Np.muted, fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon,
              size: 20, color: focused ? Np.violet : Np.muted),
          suffixIcon: trailing,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          // Lỗi hiện dưới khung để chiều cao ô không nhảy khi lỗi xuất hiện.
          errorStyle: const TextStyle(
            color: Color(0xFFE5484D),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            height: 1.6,
          ),
        ),
        validator: validator,
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
              height: 58,
              alignment: Alignment.center,
              decoration: Np.card(radius: Np.rMd),
              child: SocialMark(provider: provider, size: 24),
            ),
          ),
        ),
      );
}

class _OrRow extends StatelessWidget {
  const _OrRow();
  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider(color: Np.line)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('hoặc tiếp tục với',
                style: TextStyle(color: Np.muted, fontSize: 13)),
          ),
          Expanded(child: Divider(color: Np.line)),
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
            const Text('Chưa có tài khoản? ',
                style: TextStyle(color: Np.muted, fontSize: 15)),
            GestureDetector(
              onTap: onTap,
              child: const Text(
                'Đăng ký ngay',
                style: TextStyle(
                  color: Np.violet,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
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

  static const _red = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Np.rMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _red,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}
