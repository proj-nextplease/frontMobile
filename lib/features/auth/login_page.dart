import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Nhà cung cấp đăng nhập mạng xã hội.
///
/// Đúng ba cái web đang bật ở Supabase. Thêm cái thứ tư ở đây mà chưa bật bên
/// Dashboard thì nút bấm vào sẽ lỗi, nên danh sách này phải khớp với web.
enum SocialProvider { google, facebook, github }

extension SocialProviderX on SocialProvider {
  String get label => switch (this) {
        SocialProvider.google => 'Google',
        SocialProvider.facebook => 'Facebook',
        SocialProvider.github => 'GitHub',
      };
  String get mark => switch (this) {
        SocialProvider.google => 'G',
        SocialProvider.facebook => 'f',
        SocialProvider.github => '',
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

  /// Cho xem danh sách cơ hội mà chưa cần đăng nhập. Web cũng để /jobs công
  /// khai, nên bắt đăng nhập ngay từ màn hình đầu sẽ chặt hơn web một cách vô
  /// lý — và là cách nhanh nhất để người dùng mới gỡ app.
  final VoidCallback onSkip;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
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
    return Scaffold(
      backgroundColor: NpColors.ink,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            const _Wordmark(),
            const SizedBox(height: 10),
            const Text(
              'Đăng nhập để lưu tin, nộp đơn và xây hồ sơ năng lực.',
              style: TextStyle(color: NpColors.mutedDark, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 28),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _Field(
                    controller: _email,
                    hint: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Vui lòng nhập email.';
                      // Kiểm tra tối thiểu, có dạng a@b.c là đủ. Siết chặt hơn
                      // chỉ chặn nhầm email hợp lệ chứ không lọc thêm được gì.
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                        return 'Email không hợp lệ.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _password,
                    hint: 'Mật khẩu',
                    obscure: _obscure,
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Vui lòng nhập mật khẩu.' : null,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: NpColors.mutedDark,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorBanner(message: _error!),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() != true) return;
                      _run(() => widget.onEmailLogin(
                            _email.text.trim(),
                            _password.text,
                          ));
                    },
              style: FilledButton.styleFrom(
                backgroundColor: NpColors.emerald,
                foregroundColor: NpColors.ink,
                disabledBackgroundColor: NpColors.emerald.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: NpColors.ink),
                    )
                  : const Text('Đăng nhập',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),

            const SizedBox(height: 24),
            const _Divider(label: 'hoặc tiếp tục với'),
            const SizedBox(height: 18),

            for (final p in SocialProvider.values) ...[
              _SocialButton(
                provider: p,
                enabled: !_busy,
                onTap: () => _run(() => widget.onSocialLogin(p)),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: _busy ? null : widget.onSkip,
                child: const Text(
                  'Xem cơ hội trước đã',
                  style: TextStyle(
                    color: NpColors.mutedDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) => const Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('nextplease',
              style: TextStyle(
                color: NpColors.onDark,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
                height: 1.1,
              )),
          Text(':',
              style: TextStyle(
                color: NpColors.emerald,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
              )),
        ],
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(color: NpColors.onDark, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: NpColors.mutedDark),
          filled: true,
          fillColor: NpColors.inkSoft,
          suffixIcon: suffix,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NpRadius.md),
            borderSide: const BorderSide(color: NpColors.lineDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NpRadius.md),
            borderSide: const BorderSide(color: NpColors.lineDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NpRadius.md),
            borderSide: const BorderSide(color: NpColors.emerald, width: 1.4),
          ),
        ),
        validator: validator,
      );
}

class _Divider extends StatelessWidget {
  const _Divider({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider(color: NpColors.lineDark)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: const TextStyle(color: NpColors.mutedDark, fontSize: 13)),
          ),
          const Expanded(child: Divider(color: NpColors.lineDark)),
        ],
      );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.provider,
    required this.onTap,
    required this.enabled,
  });

  final SocialProvider provider;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: NpColors.lineDark),
          shape: const StadiumBorder(),
          foregroundColor: NpColors.onDark,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                provider.mark,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Tiếp tục với ${provider.label}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
            ),
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(NpRadius.md),
          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFCA5A5), size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Color(0xFFFCA5A5), fontSize: 14, height: 1.45),
              ),
            ),
          ],
        ),
      );
}
