import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'credential.dart';
import 'credentials_store.dart';
import 'proof_picker.dart';

/// Nộp một minh chứng mới.
///
/// Đây là chỗ mobile hơn hẳn web: chụp ảnh giấy chứng nhận hay ảnh hoạt động
/// ngay tại chỗ, thay vì phải chuyển file sang máy tính rồi mới tải lên.
class SubmitCredentialPage extends StatefulWidget {
  const SubmitCredentialPage({super.key});

  @override
  State<SubmitCredentialPage> createState() => _SubmitCredentialPageState();
}

class _SubmitCredentialPageState extends State<SubmitCredentialPage> {
  final _name = TextEditingController();
  final _position = TextEditingController();
  final _desc = TextEditingController();
  final _link = TextEditingController();

  String _category = kCredentialCategories.keys.first;
  String _roleLevel = 'MEMBER';
  List<String> _images = const [];

  DateTime? _from;
  DateTime? _to;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _position, _desc, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Còn thiếu gì. Trả câu chữ chứ không phải bool — nút xám mà im lặng vẫn
  /// bắt người dùng tự đoán mình quên ô nào.
  String? get _missing {
    if (_name.text.trim().isEmpty) return 'Chưa nhập tên hoạt động';
    if (_position.text.trim().isEmpty) return 'Chưa nhập vai trò của bạn';
    if (_images.isEmpty && _link.text.trim().isEmpty) {
      return 'Cần ít nhất một ảnh hoặc một link minh chứng';
    }
    if (_from != null && _to != null && _to!.isBefore(_from!)) {
      return 'Ngày kết thúc đang trước ngày bắt đầu';
    }
    return null;
  }

  /// Backend lưu vào cột kiểu `date`, nên phải là yyyy-MM-dd.
  String? _fmt(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 10),
      // Không cho chọn ngày TƯƠNG LAI cho mốc bắt đầu: minh chứng là việc đã
      // làm, không phải kế hoạch.
      lastDate: now,
      locale: const Locale('vi'),
    );
    if (picked == null) return;
    setState(() => start ? _from = picked : _to = picked);
  }

  Future<void> _submit() async {
    if (_missing != null || _busy) return;
    setState(() => _busy = true);

    final err = await CredentialsStore.instance.submit(
      projectName: _name.text.trim(),
      position: _position.text.trim(),
      category: _category,
      roleLevel: _roleLevel,
      description: _desc.text.trim(),
      proofLink: _link.text.trim(),
      proofImages: _images,
      startedAt: _fmt(_from),
      endedAt: _fmt(_to),
    );

    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) return Navigator.of(context).pop(true);

    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: c.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
      content: Text(err,
          style: NpType.body.copyWith(fontSize: 14, color: Colors.white)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final missing = _missing;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Nộp minh chứng', style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Np.gutter, Np.s2, Np.gutter,
            Np.s10 + MediaQuery.viewInsetsOf(context).bottom),
        children: [
          Text(
            'Nộp một hoạt động bạn đã làm kèm bằng chứng. Sau khi được duyệt, '
            'nó được cộng EXP, điểm uy tín và gắn dấu đã xác thực trên hồ sơ.',
            style: NpType.meta.copyWith(color: c.muted, height: 1.45),
          ),
          const SizedBox(height: Np.s6),

          _Field(
            label: 'Tên hoạt động',
            controller: _name,
            hint: 'Ngày hội Việc làm sinh viên 2026',
            onChanged: (_) => setState(() {}),
          ),
          _Field(
            label: 'Vai trò của bạn',
            controller: _position,
            hint: 'Trưởng ban truyền thông',
            onChanged: (_) => setState(() {}),
          ),

          const SectionLabel('Loại hình'),
          const SizedBox(height: Np.s3),
          Wrap(
            spacing: Np.s2,
            runSpacing: Np.s2,
            children: [
              for (final e in kCredentialCategories.entries)
                _Pick(
                  label: e.value,
                  on: _category == e.key,
                  onTap: () => setState(() => _category = e.key),
                ),
            ],
          ),

          const SizedBox(height: Np.s6),
          const SectionLabel('Cấp bậc'),
          const SizedBox(height: Np.s3),
          Wrap(
            spacing: Np.s2,
            children: [
              for (final e in kRoleLevels.entries)
                _Pick(
                  label: e.value,
                  on: _roleLevel == e.key,
                  onTap: () => setState(() => _roleLevel = e.key),
                ),
            ],
          ),

          const SizedBox(height: Np.s6),
          const SectionLabel('Thời gian'),
          const SizedBox(height: Np.s3),
          Row(
            children: [
              Expanded(
                child: _DateBox(
                  label: 'Bắt đầu',
                  value: _fmt(_from),
                  onTap: () => _pickDate(start: true),
                ),
              ),
              const SizedBox(width: Np.s2),
              Expanded(
                child: _DateBox(
                  label: 'Kết thúc',
                  value: _fmt(_to),
                  onTap: () => _pickDate(start: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: Np.s6),
          const SectionLabel('Ảnh minh chứng'),
          const SizedBox(height: Np.s3),
          ProofPicker(
            images: _images,
            onChanged: (v) => setState(() => _images = v),
          ),

          const SizedBox(height: Np.s5),
          _Field(
            label: 'Hoặc link minh chứng',
            controller: _link,
            hint: 'Bài đăng, album ảnh, giấy chứng nhận online…',
            onChanged: (_) => setState(() {}),
          ),

          _Field(
            label: 'Mô tả thêm',
            controller: _desc,
            hint: 'Bạn đã làm gì, kết quả ra sao…',
            lines: 4,
          ),

          const SizedBox(height: Np.s4),
          AcidButton(
            label: _busy ? 'Đang gửi…' : 'Gửi để xác thực',
            busy: _busy,
            enabled: missing == null,
            onTap: _submit,
          ),
          if (missing != null && !_busy) ...[
            const SizedBox(height: Np.s3),
            Center(
              child: Text(missing,
                  style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.lines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int lines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Np.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: NpType.label.copyWith(color: c.muted)),
          const SizedBox(height: Np.s2),
          TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines,
            onChanged: onChanged,
            style: NpType.body.copyWith(color: c.ink),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: Np.s4, vertical: Np.s3 + 2),
              hintText: hint,
              hintStyle: NpType.body.copyWith(color: c.faint),
              filled: true,
              fillColor: c.surface,
              border: _b(c.line),
              enabledBorder: _b(c.line),
              focusedBorder: _b(c.acid),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _b(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Np.rMd),
        borderSide: BorderSide(color: color),
      );
}

class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s2 + 2),
        decoration: BoxDecoration(
          color: on ? c.acid.withValues(alpha: 0.16) : c.surface,
          borderRadius: BorderRadius.circular(Np.rPill),
          border: Border.all(
              color: on ? c.acid.withValues(alpha: 0.55) : c.line),
        ),
        child: Text(label,
            style: NpType.meta.copyWith(
              fontSize: 13.5,
              color: on ? c.acidText : c.ink,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.value, required this.onTap});
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s3 + 2),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Np.rMd),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: NpType.meta.copyWith(fontSize: 11, color: c.faint)),
            const SizedBox(height: 2),
            Text(value ?? 'Chọn ngày',
                style: NpType.body.copyWith(
                  fontSize: 14,
                  color: value == null ? c.faint : c.ink,
                )),
          ],
        ),
      ),
    );
  }
}
