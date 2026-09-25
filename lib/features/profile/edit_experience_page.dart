import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/design.dart';
import '../../core/np_icons.dart';
import '../../core/widgets.dart';
import 'me_store.dart';

/// Thêm / sửa / xoá mục Kinh nghiệm.
///
/// Vì sao làm được trên app trong khi Chứng chỉ thì chưa: ExperienceDto phía
/// backend TOÀN LÀ CHỮ — title, organization, detail, startDate, endDate và
/// proofLink (chỉ một URL). Không có tải file nào cả.
///
/// Chú thích cũ trong app ghi "kinh nghiệm và chứng chỉ cần tải ảnh minh
/// chứng" là sai với phần kinh nghiệm, và nó đổ lỗi cho một ràng buộc không
/// tồn tại.
class EditExperiencePage extends StatefulWidget {
  const EditExperiencePage({super.key});

  @override
  State<EditExperiencePage> createState() => _EditExperiencePageState();
}

class _EditExperiencePageState extends State<EditExperiencePage> {
  final _api = ApiClient();
  final _me = MeStore.instance;

  late final List<Map<String, dynamic>> _items =
      _me.experienceList.map((e) => Map<String, dynamic>.from(e)).toList();

  bool _saving = false;
  bool _dirty = false;

  Future<void> _save() async {
    setState(() => _saving = true);

    // PUT /profiles/me GHI ĐÈ toàn bộ portfolio, nên phải gửi lại nguyên vẹn
    // mọi thứ khác — lấy từ raw thay vì dựng payload mới.
    final payload = Map<String, dynamic>.from(_me.raw)
      ..['experiences'] = _items;

    // Các trường chỉ-đọc: máy chủ bỏ qua, gửi kèm chỉ làm payload phình.
    for (final k in const [
      'reputationScore',
      'totalExp',
      'currentLevel',
      'publicSlug',
      'legalConsentVersion',
      'onboardingCompleted',
    ]) {
      payload.remove(k);
    }

    String? err;
    try {
      await _api.put('/profiles/me', body: payload);
      await _me.hydrate();
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
      content: Text(err,
          style: NpType.body.copyWith(fontSize: 14, color: Colors.white)),
    ));
  }

  Future<void> _edit({int? index}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExperienceForm(
        initial: index == null ? null : _items[index],
      ),
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
        title: Text('Xoá mục này?', style: NpType.title.copyWith(color: c.ink)),
        content: Text(
            'Mục "${_items[index]['title'] ?? ''}" sẽ bị gỡ khỏi hồ sơ của bạn.',
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
        title: Text('Kinh nghiệm', style: NpType.h1.copyWith(color: c.ink)),
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
                    // Chưa đổi gì thì nút Lưu phải XÁM thật, không phải xanh
                    // rồi bấm không có gì xảy ra.
                    color: _dirty && !_saving ? c.acidText : c.faint,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Np.gutter, Np.s2, Np.gutter, Np.navInset),
        children: [
          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: Np.s8),
              decoration: Np.card(c),
              child: Column(
                children: [
                  NpIco(NpIcon.jobs, size: 24, color: c.faint),
                  const SizedBox(height: Np.s3),
                  Text('Chưa có mục kinh nghiệm nào',
                      style: NpType.title.copyWith(fontSize: 16, color: c.ink)),
                  const SizedBox(height: Np.s2),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Np.s5),
                    child: Text(
                      'Đây là phần nhà tuyển dụng đọc đầu tiên. Thêm cả việc '
                      'làm thêm, hoạt động CLB hay dự án môn học.',
                      textAlign: TextAlign.center,
                      style: NpType.meta.copyWith(color: c.muted, height: 1.45),
                    ),
                  ),
                ],
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
          AcidButton(
            label: 'Thêm mục kinh nghiệm',
            onTap: () => _edit(),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final title = '${item['title'] ?? ''}'.trim();
    final org = '${item['organization'] ?? ''}'.trim();
    final from = '${item['startDate'] ?? ''}'.trim();
    final to = '${item['endDate'] ?? ''}'.trim();
    final verified = item['verified'] == true;

    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(Np.s4),
        decoration: Np.card(c, radius: Np.rMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title.isEmpty ? 'Kinh nghiệm' : title,
                            style: NpType.body.copyWith(
                                color: c.ink, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (verified) ...[
                        const SizedBox(width: Np.s2),
                        MetaChip(label: 'Đã xác thực', accent: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [org, if (from.isNotEmpty || to.isNotEmpty) '$from — $to']
                        .where((s) => s.trim().isNotEmpty)
                        .join(' · '),
                    style: NpType.meta.copyWith(color: c.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Np.s2),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(Np.s1),
                child: NpIco(NpIcon.close, size: 17, color: c.faint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form một mục kinh nghiệm.
class _ExperienceForm extends StatefulWidget {
  const _ExperienceForm({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_ExperienceForm> createState() => _ExperienceFormState();
}

class _ExperienceFormState extends State<_ExperienceForm> {
  late final _title = TextEditingController(text: _s('title'));
  late final _org = TextEditingController(text: _s('organization'));
  late final _detail = TextEditingController(text: _s('detail'));
  late final _from = TextEditingController(text: _s('startDate'));
  late final _to = TextEditingController(text: _s('endDate'));
  late final _proof = TextEditingController(text: _s('proofLink'));

  String _s(String k) => '${widget.initial?[k] ?? ''}';

  @override
  void dispose() {
    for (final c in [_title, _org, _detail, _from, _to, _proof]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ba trường backend đánh @NotBlank. Kiểm ở đây để nút Lưu không sáng rồi
  /// bấm mới nhận lỗi 400.
  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _org.text.trim().isNotEmpty &&
      _detail.text.trim().isNotEmpty;

  void _submit() {
    Navigator.of(context).pop(<String, dynamic>{
      if (widget.initial?['id'] != null) 'id': widget.initial!['id'],
      'title': _title.text.trim(),
      'organization': _org.text.trim(),
      'detail': _detail.text.trim(),
      'startDate': _from.text.trim(),
      'endDate': _to.text.trim(),
      'proofLink': _proof.text.trim(),
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
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.line,
                      borderRadius: BorderRadius.circular(Np.rPill),
                    ),
                  ),
                ),
                const SizedBox(height: Np.s5),
                Text(widget.initial == null ? 'Thêm kinh nghiệm' : 'Sửa mục',
                    style: NpType.h1.copyWith(color: c.ink)),
                const SizedBox(height: Np.s5),

                _Field(
                  label: 'VAI TRÒ *',
                  controller: _title,
                  hint: 'VD: Cộng tác viên truyền thông',
                  onChanged: () => setState(() {}),
                ),
                _Field(
                  label: 'TỔ CHỨC *',
                  controller: _org,
                  hint: 'VD: CLB Truyền thông ĐH ABC',
                  onChanged: () => setState(() {}),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'TỪ',
                        controller: _from,
                        hint: '09/2025',
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: Np.s3),
                    Expanded(
                      child: _Field(
                        label: 'ĐẾN',
                        controller: _to,
                        hint: 'Hiện tại',
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                ),
                _Field(
                  label: 'MÔ TẢ *',
                  controller: _detail,
                  hint: 'Bạn đã làm gì, kết quả ra sao?',
                  maxLines: 4,
                  onChanged: () => setState(() {}),
                ),
                _Field(
                  label: 'LINK MINH CHỨNG',
                  controller: _proof,
                  hint: 'Link bài viết, sản phẩm, giấy xác nhận…',
                  onChanged: () => setState(() {}),
                ),

                const SizedBox(height: Np.s2),
                Text(
                  'Mục tự khai chưa có dấu "Đã xác thực". Muốn được xác thực '
                  'và cộng điểm uy tín thì nộp qua mục Minh chứng.',
                  style: NpType.meta
                      .copyWith(fontSize: 12, color: c.muted, height: 1.45),
                ),

                const SizedBox(height: Np.s5),
                AcidButton(
                  label: 'Xong',
                  enabled: _valid,
                  onTap: _submit,
                ),
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
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final int maxLines;

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
            maxLines: maxLines,
            onChanged: (_) => onChanged(),
            style: NpType.body.copyWith(color: c.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: NpType.body.copyWith(color: c.faint),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: Np.s4, vertical: Np.s3),
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
