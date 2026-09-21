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
    final c = Np.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      /* Chữ thanh trạng thái phải NGƯỢC với nền. iOS đọc statusBarBrightness
         (mô tả NỀN), Android đọc statusBarIconBrightness (mô tả ICON) — hai
         trường ngược nghĩa nhau. */
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: ListView(
            // Đệm đáy cộng chiều cao bàn phím, nếu không bàn phím che mất nút.
            padding: EdgeInsets.fromLTRB(
              Np.gutter, Np.s6, Np.gutter,
              Np.s8 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              const SectionLabel('Đăng nhập'),
              const SizedBox(height: Np.s5),

              // Tiêu đề khổng lồ cạnh nhãn 11px ở trên — đây chính là độ
              // tương phản cỡ chữ mà bốn bản trước thiếu.
              Text('Chào bạn,', style: NpType.display),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('quay lại nhé', style: NpType.display),
                  // Dấu chấm acid: điểm màu duy nhất ở nửa trên màn hình.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7, left: 3),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: c.acid,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Np.s10),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _Field(
                      controller: _email,
                      focusNode: _emailFocus,
                      label: 'Email',
                      hint: 'ban@truong.edu.vn',
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
                    const SizedBox(height: Np.s5),
                    _Field(
                      controller: _password,
                      focusNode: _passwordFocus,
                      label: 'Mật khẩu',
                      hint: 'Ít nhất 6 ký tự',
                      obscure: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Chưa nhập mật khẩu' : null,
                      trailing: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: Np.s3),
                          child: Text(
                            _obscure ? 'Hiện' : 'Ẩn',
                            style: NpType.meta.copyWith(
                              color: c.acidText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Np.s4),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _busy ? null : _forgotPassword,
                  child: Text('Quên mật khẩu?',
                      style: NpType.meta.copyWith(fontWeight: FontWeight.w500)),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: Np.s5),
                _ErrorNote(message: _error!),
              ],

              const SizedBox(height: Np.s6),
              AcidButton(
                label: 'Đăng nhập',
                busy: _busy,
                onTap: _submit,
                icon: Icons.arrow_forward_rounded,
              ),

              const SizedBox(height: Np.s8),
              const _OrRow(),
              const SizedBox(height: Np.s5),

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
                      const SizedBox(width: Np.s3),
                  ],
                ],
              ),

              const SizedBox(height: Np.s8),
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : widget.onSkip,
                  child: Text('Xem cơ hội trước đã',
                      style: NpType.meta.copyWith(
                        color: c.faint,
                        fontWeight: FontWeight.w500,
                      )),
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

  // Luồng này chưa dựng. Nói thẳng ra thay vì để nút bấm vào không có gì xảy
  // ra — người dùng sẽ tưởng app hỏng.
  void _forgotPassword() => _notYet('Đặt lại mật khẩu');

  void _notYet(String what) {
    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.surfaceHi,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Np.rSm),
          side: BorderSide(color: c.line),
        ),
        content: Text(
          '$what chưa có trong app. Tạm thời dùng trên website nhé.',
          style: NpType.body.copyWith(fontSize: 14),
        ),
      ),
    );
  }
}

/// Ô nhập kiểu "gạch chân", không phải hộp.
///
/// Đây là thay đổi bố cục đáng kể nhất so với bốn bản trước: hộp viền kín làm
/// biểu mẫu trông nặng và chiếm nhiều chiều cao. Gạch chân nhẹ hơn hẳn, và
/// dồn sự chú ý vào chính chữ người dùng gõ. Vạch đổi sang acid khi đang gõ —
/// đó là toàn bộ chỉ báo tiêu điểm cần có.
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
    final c = Np.of(context);
    final focused = focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: NpType.label.copyWith(color: focused ? c.acidText : c.faint),
        ),
        const SizedBox(height: Np.s2),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscure,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                onFieldSubmitted: onSubmitted,
                autocorrect: false,
                enableSuggestions: false,
                cursorColor: c.acidText,
                cursorWidth: 1.6,
                style: NpType.body.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: NpType.body.copyWith(
                    fontSize: 17,
                    color: c.faint,
                    fontWeight: FontWeight.w400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.only(bottom: Np.s3),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  // Lỗi nằm dưới vạch nên chiều cao ô không nhảy khi lỗi hiện.
                  errorStyle: NpType.meta.copyWith(
                    color: c.danger,
                    fontSize: 12.5,
                    height: 1.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                validator: validator,
              ),
            ),
            ?trailing,
          ],
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: focused ? 1.6 : 1,
          color: focused ? c.acidText : c.line,
        ),
      ],
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
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Semantics(
        button: true,
        label: 'Đăng nhập bằng ${provider.label}',
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: Np.card(c, radius: Np.rMd),
              child: SocialMark(provider: provider, size: 22),
            ),
          ),
        ),
      );
  }
}

class _OrRow extends StatelessWidget {
  const _OrRow();
  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: c.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Np.s3),
          child: Text('hoặc', style: NpType.meta.copyWith(color: c.faint)),
        ),
        Expanded(child: Divider(color: c.line)),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
        padding: const EdgeInsets.all(Np.s3 + 2),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Np.rSm),
          border: Border.all(color: c.danger.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: c.danger, size: 18),
            const SizedBox(width: Np.s2 + 2),
            Expanded(
              child: Text(
                message,
                style: NpType.meta.copyWith(color: c.danger, fontSize: 13.5),
              ),
            ),
          ],
        ),
      );
  }
}
