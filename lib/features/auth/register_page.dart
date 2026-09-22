import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'auth_service.dart';

/// Đăng ký tài khoản ứng viên.
///
/// ─── Vì sao màn này phải có ──────────────────────────────────────────────
/// Trước đây app CHỈ có đăng nhập. Người tải app về mà chưa có tài khoản thì
/// không vào được, phải mở website đăng ký rồi mới quay lại — đủ để mất phần
/// lớn người dùng mới.
///
/// ─── Luồng ───────────────────────────────────────────────────────────────
/// Hai bước, đúng như backend:
///   1. POST /auth/candidates/register/request-otp  → registrationId + gửi mã
///      6 số qua email
///   2. POST /auth/candidates/register/verify-otp   → tạo tài khoản thật
///
/// Mật khẩu gửi ở CẢ HAI bước (đó là hợp đồng của backend, không phải nhầm),
/// nên nó được giữ trong state giữa hai bước chứ không bắt gõ lại.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.onDone});

  /// Gọi khi đã tạo tài khoản xong. Nơi gọi tự quyết định làm gì tiếp —
  /// thường là đóng màn này và điền sẵn email vào ô đăng nhập.
  final void Function(String email) onDone;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _api = ApiClient();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _studentEmail = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();

  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  /// null = đang ở bước nhập thông tin. Có giá trị = đã gửi mã, đang chờ nhập.
  String? _registrationId;
  DateTime? _expiresAt;

  @override
  void dispose() {
    for (final c in [_name, _email, _studentEmail, _password, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Quy tắc lấy từ CandidateRegistrationOtpRequest: 6–25 ký tự, phải có chữ
  /// thường, chữ hoa và chữ số. Kiểm ở đây để người dùng biết NGAY thay vì
  /// điền hết form rồi nhận một dòng lỗi tiếng Anh từ Bean Validation.
  String? get _passwordProblem {
    final v = _password.text;
    if (v.isEmpty) return null;
    if (v.length < 6 || v.length > 25) return 'Mật khẩu cần 6–25 ký tự';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Cần ít nhất một chữ thường';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Cần ít nhất một chữ HOA';
    if (!RegExp(r'\d').hasMatch(v)) return 'Cần ít nhất một chữ số';
    return null;
  }

  /// Còn thiếu gì để gửi được mã. Trả null khi đã đủ.
  ///
  /// Trả về CÂU CHỮ chứ không phải bool: nút xám mà không nói vì sao vẫn bắt
  /// người dùng tự đoán mình quên ô nào. Trước đây tệ hơn nữa — nút vẫn xanh
  /// và bấm không ra gì.
  String? get _missing {
    if (_name.text.trim().isEmpty) return 'Chưa nhập họ và tên';
    if (!_email.text.trim().contains('@')) return 'Email đăng nhập chưa hợp lệ';
    if (!_studentEmail.text.trim().contains('@')) {
      return 'Email sinh viên chưa hợp lệ';
    }
    if (_password.text.isEmpty) return 'Chưa nhập mật khẩu';
    return _passwordProblem;
  }

  bool get _canRequest => !_busy && _missing == null;

  Future<void> _requestOtp() async {
    if (!_canRequest) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final d = await _api.post('/auth/candidates/register/request-otp', body: {
        'email': _email.text.trim().toLowerCase(),
        'password': _password.text,
        'displayName': _name.text.trim(),
        'studentEmail': _studentEmail.text.trim().toLowerCase(),
      });
      if (!mounted) return;
      final m = d is Map<String, dynamic> ? d : const <String, dynamic>{};
      setState(() {
        _registrationId = '${m['registrationId'] ?? ''}';
        _expiresAt = m['expiresAt'] == null
            ? null
            : DateTime.tryParse('${m['expiresAt']}')?.toLocal();
        // devOtp chỉ có khi backend bật app.auth.registration.expose-dev-otp.
        // Điền sẵn giúp môi trường dev đỡ phải mở hộp thư; production không
        // trả trường này nên ô vẫn trống.
        final dev = m['devOtp'];
        if (dev != null) _otp.text = '$dev';
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Future<void> _verify() async {
    if (_busy || _otp.text.trim().length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _api.post('/auth/candidates/register/verify-otp', body: {
        'registrationId': _registrationId,
        'otp': _otp.text.trim(),
        'password': _password.text,
      });
      if (!mounted) return;
      widget.onDone(_email.text.trim().toLowerCase());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final otpStep = _registrationId != null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text(otpStep ? 'Xác nhận email' : 'Tạo tài khoản',
            style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Np.gutter, Np.s2, Np.gutter,
            Np.s10 + MediaQuery.viewInsetsOf(context).bottom),
        children: [
          // Ô lỗi LUÔN chiếm một vị trí trong danh sách, rỗng thì thu về 0.
          //
          // Trước đây nó là `if (_error != null) ...[...]`, nên mỗi lần lỗi
          // hiện ra hay biến mất là mọi widget bên dưới DỊCH 2 chỗ. Flutter
          // khớp widget không key theo (kiểu, vị trí), nên ô "Họ và tên" bị
          // khớp với ô "Email sinh viên" — hai TextEditingController khác
          // nhau dùng chung một Element. EditableText giữ GlobalKey bên
          // trong, và đó đúng là kiểu lỗi
          // '_elements.contains(element) is not true'.
          //
          // Giữ cấu trúc bất biến thì không có gì để dịch.
          _error == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: Np.s5),
                  child: Container(
                    padding: const EdgeInsets.all(Np.s4),
                    decoration: BoxDecoration(
                      color: c.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(Np.rMd),
                      border:
                          Border.all(color: c.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!,
                        style: NpType.meta.copyWith(color: c.danger)),
                  ),
                ),

          if (otpStep) ..._otpStep(c) else ..._formStep(c),
        ],
      ),
    );
  }

  List<Widget> _formStep(NpColors c) => [
        _Field(
          key: const ValueKey('name'),
          label: 'Họ và tên',
          controller: _name,
          hint: 'Nguyễn Văn A',
          onChanged: (_) => setState(() {}),
        ),
        _Field(
          key: const ValueKey('email'),
          label: 'Email đăng nhập',
          controller: _email,
          hint: 'ban@gmail.com',
          keyboard: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
        ),
        _Field(
          key: const ValueKey('studentEmail'),
          label: 'Email sinh viên',
          controller: _studentEmail,
          hint: 'ban@fpt.edu.vn',
          keyboard: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
          note: 'Dùng để xác minh bạn đang là sinh viên. '
              'Có thể trùng email đăng nhập.',
        ),
        _Field(
          key: const ValueKey('password'),
          label: 'Mật khẩu',
          controller: _password,
          hint: 'Ít nhất 6 ký tự',
          obscure: !_showPassword,
          onChanged: (_) => setState(() {}),
          error: _passwordProblem,
          trailing: GestureDetector(
            onTap: () => setState(() => _showPassword = !_showPassword),
            behavior: HitTestBehavior.opaque,
            child: Text(_showPassword ? 'Ẩn' : 'Hiện',
                style: NpType.meta.copyWith(
                  color: c.acidText,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
        Text(
          'Cần chữ thường, chữ HOA và chữ số.',
          style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted),
        ),
        const SizedBox(height: Np.s6),
        AcidButton(
          label: _busy ? 'Đang gửi mã…' : 'Gửi mã xác nhận',
          busy: _busy,
          enabled: _canRequest,
          onTap: _requestOtp,
        ),
        if (_missing != null && !_busy) ...[
          const SizedBox(height: Np.s3),
          Center(
            child: Text(_missing!,
                style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted)),
          ),
        ],
      ];

  List<Widget> _otpStep(NpColors c) => [
        Text('Đã gửi mã 6 số tới', style: NpType.meta.copyWith(color: c.muted)),
        const SizedBox(height: Np.s1),
        Text(_email.text.trim().toLowerCase(),
            style: NpType.title.copyWith(fontSize: 17, color: c.ink)),
        if (_expiresAt != null) ...[
          const SizedBox(height: Np.s2),
          Text('Mã hết hạn lúc ${_hhmm(_expiresAt!)}',
              style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted)),
        ],
        const SizedBox(height: Np.s6),
        _Field(
          key: const ValueKey('otp'),
          label: 'Mã xác nhận',
          controller: _otp,
          hint: '000000',
          keyboard: TextInputType.number,
          // Chỉ cho gõ số và tối đa 6 ký tự: backend bắt đúng \d{6}, chặn
          // ngay ở bàn phím thì không ai phải nhận lỗi vì gõ thừa.
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Np.s2),
        AcidButton(
          label: _busy ? 'Đang tạo tài khoản…' : 'Xác nhận',
          busy: _busy,
          enabled: _otp.text.trim().length == 6,
          onTap: _verify,
        ),
        if (_otp.text.trim().length != 6 && !_busy) ...[
          const SizedBox(height: Np.s3),
          Center(
            child: Text('Mã gồm 6 chữ số',
                style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted)),
          ),
        ],
        const SizedBox(height: Np.s4),
        Center(
          child: GestureDetector(
            onTap: _busy
                ? null
                : () => setState(() {
                      // Quay lại bước nhập, KHÔNG gửi lại mã ngay: người dùng
                      // thường bấm "quay lại" vì gõ sai email, và gửi thêm một
                      // mã tới địa chỉ sai chẳng giúp gì.
                      _registrationId = null;
                      _otp.clear();
                      _error = null;
                    }),
            behavior: HitTestBehavior.opaque,
            child: Text('Sửa thông tin / gửi lại mã',
                style: NpType.meta.copyWith(
                  color: c.acidText,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
      ];

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.note,
    this.error,
    this.obscure = false,
    this.keyboard,
    this.trailing,
    this.formatters,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? note;
  final String? error;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? trailing;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final bad = error != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: Np.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: NpType.label.copyWith(color: c.muted)),
          const SizedBox(height: Np.s2),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            inputFormatters: formatters,
            onChanged: onChanged,
            autocorrect: false,
            enableSuggestions: false,
            style: NpType.body.copyWith(color: c.ink),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: Np.s4, vertical: Np.s3 + 2),
              hintText: hint,
              hintStyle: NpType.body.copyWith(color: c.faint),
              filled: true,
              fillColor: c.surface,
              suffixIcon: trailing == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: Np.s4),
                      child: Center(widthFactor: 1, child: trailing),
                    ),
              border: _b(c.line),
              enabledBorder: _b(bad ? c.danger.withValues(alpha: 0.6) : c.line),
              focusedBorder: _b(bad ? c.danger : c.acid),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: Np.s1 + 2),
            Text(error!,
                style: NpType.meta.copyWith(fontSize: 12, color: c.danger)),
          ] else if (note != null) ...[
            const SizedBox(height: Np.s1 + 2),
            Text(note!,
                style: NpType.meta.copyWith(fontSize: 12, color: c.muted)),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _b(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Np.rMd),
        borderSide: BorderSide(color: color),
      );
}

/// Tấm trượt lên để nhập email nhận link đặt lại mật khẩu.
Future<void> showForgotPasswordSheet(BuildContext context,
        {String? initialEmail}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotSheet(initialEmail: initialEmail),
    );

class _ForgotSheet extends StatefulWidget {
  const _ForgotSheet({this.initialEmail});
  final String? initialEmail;

  @override
  State<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends State<_ForgotSheet> {
  final _auth = AuthService();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final v = _email.text.trim();
    if (v.isEmpty || !v.contains('@') || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await _auth.sendPasswordReset(v);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _sent = err == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Np.rLg)),
      ),
      padding: EdgeInsets.fromLTRB(Np.gutter, Np.s5, Np.gutter, bottom + Np.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề đổi theo bước. Sau khi gửi xong, lặp lại "Quên mật khẩu"
          // là nói về việc đã qua; điều người dùng cần biết lúc đó là phải
          // làm gì tiếp.
          Text(_sent ? 'Kiểm tra hộp thư' : 'Quên mật khẩu',
              style: NpType.h1.copyWith(color: c.ink)),
          const SizedBox(height: Np.s2),

          if (_sent) ...[
            const SizedBox(height: Np.s2),
            // Địa chỉ đứng riêng một dòng chứ không nhét giữa câu: người dùng
            // cần LIẾC là thấy mình gõ đúng email chưa, không phải đọc hết câu.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: Np.s4, vertical: Np.s3),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Np.rMd),
                border: Border.all(color: c.line),
              ),
              child: Text(_email.text.trim(),
                  style: NpType.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            const SizedBox(height: Np.s4),

            // Ba dòng, mỗi dòng một việc: đã gửi gì, làm gì tiếp, không thấy
            // thì tìm ở đâu. Bản trước gộp thành hai đoạn văn, và bỏ sót hẳn
            // chuyện email rơi vào Spam — thứ hỏng thường gặp nhất.
            _Line(text: 'Nếu địa chỉ này đã đăng ký, link đặt lại mật khẩu '
                'vừa được gửi tới.'),
            _Line(text: 'Bấm link để đặt mật khẩu mới, rồi quay lại đây '
                'đăng nhập.'),
            _Line(text: 'Không thấy? Tìm thử trong mục Spam hoặc Quảng cáo.'),

            const SizedBox(height: Np.s6),
            AcidButton(
              label: 'Quay lại đăng nhập',
              onTap: () => Navigator.of(context).pop(),
            ),
          ] else ...[
            Text(
              'Nhập email của bạn, chúng tôi sẽ gửi link đặt lại mật khẩu.',
              style: NpType.body.copyWith(color: c.muted),
            ),
            const SizedBox(height: Np.s5),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofocus: true,
              style: NpType.body.copyWith(color: c.ink),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: Np.s4, vertical: Np.s3 + 2),
                hintText: 'ban@gmail.com',
                hintStyle: NpType.body.copyWith(color: c.faint),
                filled: true,
                fillColor: c.surface,
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
            if (_error != null) ...[
              const SizedBox(height: Np.s3),
              Text(_error!,
                  style: NpType.meta.copyWith(color: c.danger)),
            ],
            const SizedBox(height: Np.s5),
            AcidButton(
              label: _busy ? 'Đang gửi…' : 'Gửi link đặt lại',
              busy: _busy,
              enabled: _email.text.trim().contains('@'),
              onTap: _send,
            ),
          ],
        ],
      ),
    );
  }
}

/// Một dòng hướng dẫn, có chấm đầu dòng nhỏ.
///
/// Chấm chứ không phải số thứ tự: ba dòng này không phải ba bước phải làm
/// theo trình tự — dòng cuối chỉ cần đọc khi có sự cố.
class _Line extends StatelessWidget {
  const _Line({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Np.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 9, right: Np.s3),
            decoration: BoxDecoration(color: c.faint, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(text,
                style: NpType.body.copyWith(color: c.muted, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
