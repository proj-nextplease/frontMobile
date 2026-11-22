import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/design.dart';
import '../../core/widgets.dart';
import 'me_store.dart';

/// Thêm / sửa / xoá Bằng cấp & chứng chỉ — bước 4 của trang sửa portfolio web.
///
/// Mỗi mục: tên, đơn vị cấp, thời gian cấp (MM/YY — backend bắt đúng mẫu
/// này qua @Pattern của CredentialDto) và một tệp đính kèm tuỳ chọn. Web nhận
/// cả PDF; app nhận ẢNH chụp bằng cấp (đủ cho phần lớn người dùng trên điện
/// thoại). Tệp PDF đã tải lên từ web được giữ nguyên khi sửa các trường khác.
class EditCredentialsPage extends StatefulWidget {
  const EditCredentialsPage({super.key});

  @override
  State<EditCredentialsPage> createState() => _EditCredentialsPageState();
}

class _EditCredentialsPageState extends State<EditCredentialsPage> {
  final _me = MeStore.instance;

  late final List<Map<String, dynamic>> _items =
      _me.credentialList.map((e) => Map<String, dynamic>.from(e)).toList();

  bool _saving = false;
  bool _dirty = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    String? err;
    try {
      await _me.saveWith({'credentials': _items});
    } on ApiException catch (e) {
      err = e.message;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) {
      Navigator.of(context).pop(true);
      return;
    }
    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: c.danger,
      behavior: SnackBarBehavior.floating,
      content: Text(err,
          style: NpType.body.copyWith(fontSize: 14, color: Colors.white)),
    ));
  }

  Future<void> _edit({int? index}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _CredentialForm(initial: index == null ? null : _items[index]),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
      _dirty = true;
    });
  }

  Future<void> _delete(int index) async {
    final c = Np.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rLg)),
        title: Text('Xoá chứng chỉ này?',
            style: NpType.title.copyWith(color: c.ink)),
        content: Text(
            '"${_items[index]['name'] ?? ''}" sẽ bị gỡ khỏi hồ sơ của bạn.',
            style: NpType.body.copyWith(color: c.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Huỷ', style: NpType.button.copyWith(color: c.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Xoá', style: NpType.button.copyWith(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _items.removeAt(index);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Chứng chỉ', style: NpType.h1.copyWith(color: c.ink)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Np.gutter),
            child: GestureDetector(
              onTap: _dirty && !_saving ? _save : null,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Text(
                  _saving ? 'Đang lưu…' : 'Lưu',
                  style: NpType.button.copyWith(
                    fontSize: 15,
                    color: _dirty && !_saving ? c.acidText : c.faint,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(Np.gutter, Np.s2, Np.gutter, Np.navInset),
        children: [
          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: Np.s8, horizontal: Np.s5),
              decoration: Np.card(c),
              child: Text(
                'Chưa có bằng cấp hay chứng chỉ nào. Thêm IELTS, chứng chỉ '
                'khoá học, giấy khen… kèm ảnh chụp để nhà tuyển dụng xem.',
                textAlign: TextAlign.center,
                style: NpType.meta.copyWith(color: c.muted, height: 1.45),
              ),
            )
          else
            for (var i = 0; i < _items.length; i++) ...[
              _Row(
                item: _items[i],
                onEdit: () => _edit(index: i),
                onDelete: () => _delete(i),
              ),
              const SizedBox(height: Np.s2),
            ],
          const SizedBox(height: Np.s4),
          AcidButton(label: 'Thêm chứng chỉ', onTap: () => _edit()),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final name = '${item['name'] ?? ''}'.trim();
    final issuer = '${item['issuer'] ?? ''}'.trim();
    final at = '${item['issuedAt'] ?? ''}'.trim();
    final file = '${item['fileName'] ?? ''}'.trim();
    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(Np.s4),
        decoration: Np.card(c),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Chưa đặt tên' : name,
                      style: NpType.body
                          .copyWith(color: c.ink, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text([issuer, at].where((s) => s.isNotEmpty).join(' · '),
                      style: NpType.meta.copyWith(color: c.muted)),
                  if (file.isNotEmpty)
                    Text('Đính kèm: $file',
                        style: NpType.meta.copyWith(color: c.faint)),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: c.faint),
              tooltip: 'Xoá',
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialForm extends StatefulWidget {
  const _CredentialForm({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_CredentialForm> createState() => _CredentialFormState();
}

class _CredentialFormState extends State<_CredentialForm> {
  late final _name = TextEditingController(text: _s('name'));
  late final _issuer = TextEditingController(text: _s('issuer'));
  late final _issuedAt = TextEditingController(text: _s('issuedAt'));
  late String _fileName = _s('fileName');
  late String _fileData = _s('fileData');
  late String _fileType = _s('fileType');
  bool _picking = false;

  String _s(String k) => '${widget.initial?[k] ?? ''}';

  @override
  void dispose() {
    for (final c in [_name, _issuer, _issuedAt]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Cùng quy tắc với web: MM/YY, không sau tháng hiện tại.
  String? get _dateError {
    final v = _issuedAt.text.trim();
    if (v.isEmpty) return null;
    final m = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$').firstMatch(v);
    if (m == null) return 'Đúng định dạng MM/YY (ví dụ: 06/26)';
    final now = DateTime.now();
    final month = int.parse(m[1]!), year = 2000 + int.parse(m[2]!);
    if (year > now.year || (year == now.year && month > now.month)) {
      return 'Thời gian cấp không được sau tháng hiện tại';
    }
    return null;
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _issuer.text.trim().isNotEmpty &&
      _issuedAt.text.trim().isNotEmpty &&
      _dateError == null;

  Future<void> _pickFile() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final f = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Tệp bằng cấp/chứng chỉ không được vượt quá 10MB.')));
        }
        return;
      }
      setState(() {
        _fileData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        _fileType = 'image/jpeg';
        _fileName = f.name.isNotEmpty ? f.name : 'chung-chi.jpg';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không mở được thư viện ảnh.')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    Navigator.of(context).pop(<String, dynamic>{
      // Web đặt id bằng thời điểm tạo; giữ id cũ khi sửa.
      'id': widget.initial?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _name.text.trim(),
      'issuer': _issuer.text.trim(),
      'issuedAt': _issuedAt.text.trim(),
      'fileName': _fileName,
      'fileData': _fileData,
      'fileType': _fileType,
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Np.rLg)),
        ),
        padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s4, Np.gutter, Np.s6),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.initial == null ? 'Thêm chứng chỉ' : 'Sửa chứng chỉ',
                    style: NpType.h1.copyWith(color: c.ink)),
                const SizedBox(height: Np.s5),
                _Field(
                  label: 'TÊN BẰNG CẤP / CHỨNG CHỈ *',
                  controller: _name,
                  hint: 'VD: IELTS 7.0 / Google UX Design Certificate',
                  onChanged: () => setState(() {}),
                ),
                _Field(
                  label: 'ĐƠN VỊ CẤP *',
                  controller: _issuer,
                  hint: 'VD: British Council / Coursera',
                  onChanged: () => setState(() {}),
                ),
                _Field(
                  label: 'THỜI GIAN CẤP (MM/YY) *',
                  controller: _issuedAt,
                  hint: 'VD: 06/26',
                  monthYear: true,
                  onChanged: () => setState(() {}),
                ),
                if (_dateError != null) ...[
                  Text(_dateError!, style: NpType.meta.copyWith(color: c.danger)),
                  const SizedBox(height: Np.s4),
                ],
                Text('ẢNH BẰNG CẤP / CHỨNG CHỈ',
                    style: NpType.label.copyWith(color: c.muted)),
                const SizedBox(height: Np.s2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fileName.isEmpty ? 'Chưa đính kèm (không bắt buộc)' : _fileName,
                        style: NpType.meta.copyWith(
                            color: _fileName.isEmpty ? c.faint : c.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _picking ? null : _pickFile,
                      child: Text(_fileName.isEmpty ? 'Chọn ảnh' : 'Đổi ảnh',
                          style: NpType.button
                              .copyWith(fontSize: 14, color: c.acidText)),
                    ),
                    if (_fileName.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() {
                          _fileName = _fileData = _fileType = '';
                        }),
                        child: Text('Gỡ',
                            style: NpType.button
                                .copyWith(fontSize: 14, color: c.danger)),
                      ),
                  ],
                ),
                const SizedBox(height: Np.s5),
                AcidButton(label: 'Xong', enabled: _valid, onTap: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.monthYear = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  /// Ô MM/YY: bàn phím số, tự chèn "/".
  final bool monthYear;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Np.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: NpType.label.copyWith(color: c.muted)),
          const SizedBox(height: Np.s2),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            keyboardType: monthYear ? TextInputType.number : null,
            inputFormatters: monthYear ? [_MonthYearMask()] : null,
            style: NpType.body.copyWith(color: c.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: NpType.body.copyWith(color: c.faint),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: Np.s4, vertical: Np.s3),
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
        ],
      ),
    );
  }
}

/// 0626 → 06/26.
class _MonthYearMask extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 4) d = d.substring(0, 4);
    final t = d.length > 2 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
