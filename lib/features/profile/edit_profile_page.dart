import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'me_store.dart';

/// Sửa hồ sơ.
///
/// ─── Điều nguy hiểm nhất ở màn này ───────────────────────────────────────
/// `PUT /profiles/me` nhận trọn bộ PortfolioRequest và GHI ĐÈ tất cả. Gửi
/// thiếu `experiences` là xoá sạch kinh nghiệm, thiếu `avatar` là mất ảnh.
/// Nên payload dựng TỪ bản gốc `MeStore.raw` rồi mới chèn phần vừa sửa lên —
/// không bao giờ dựng từ số không.
///
/// Đây đúng là lỗi đã xảy ra một lần ở trang doanh nghiệp bên web, nơi
/// handleSave bỏ sót vài trường và mỗi lần lưu là xoá chúng.
///
/// ─── Phạm vi ─────────────────────────────────────────────────────────────
/// Chỉ những trường gõ được bằng bàn phím: tên, giới thiệu, trường, nơi ở,
/// mô tả, trạng thái tìm việc, và KỸ NĂNG. Kinh nghiệm và chứng chỉ cần tải
/// ảnh minh chứng và đi qua luồng xác thực nên vẫn làm trên website — nhưng
/// chúng được mang nguyên vẹn trong payload nên không mất.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _api = ApiClient();
  final _me = MeStore.instance;

  late final _name = TextEditingController(text: _me.name ?? '');
  late final _headline = TextEditingController(text: _me.headline ?? '');
  late final _school = TextEditingController(text: _me.school ?? '');
  late final _location = TextEditingController(text: _me.location ?? '');
  late final _bio = TextEditingController(text: _me.bio ?? '');
  final _skillInput = TextEditingController();

  /// Giữ nguyên cách viết hoa người dùng đã nhập, KHÔNG dùng bản chữ thường
  /// trong MeStore.skills — bản đó chỉ để so khớp. Lưu lại bản thường hoá sẽ
  /// biến "JavaScript" trong hồ sơ thành "javascript".
  late List<String> _skills = _originalSkills();

  late bool _openToWork = _me.openToWork;

  /// Danh sách gợi ý từ /skills. Rỗng cũng không sao — người dùng vẫn gõ tay
  /// được, và backend tự tạo kỹ năng mới nếu tên chưa có.
  List<String> _catalog = const [];

  bool _saving = false;

  List<String> _originalSkills() {
    final raw = _me.raw['skills'];
    if (raw is List) {
      return raw.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    for (final c in [_name, _headline, _school, _location, _bio, _skillInput]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final d = await _api.get('/skills');
      if (d is! List || !mounted) return;
      setState(() => _catalog = d
          .whereType<Map<String, dynamic>>()
          .map((m) => '${m['name'] ?? ''}'.trim())
          .where((s) => s.isNotEmpty)
          .toList());
    } on ApiException {
      // Gợi ý là tiện ích, không phải điều kiện. Hỏng thì vẫn gõ tay được.
    }
  }

  /// So khớp không phân biệt hoa thường để không thêm trùng "Figma" và "figma".
  bool _has(String s) =>
      _skills.any((e) => e.toLowerCase() == s.trim().toLowerCase());

  void _addSkill(String s) {
    final v = s.trim();
    if (v.isEmpty || _has(v)) return;
    setState(() {
      _skills = [..._skills, v];
      _skillInput.clear();
    });
  }

  void _removeSkill(String s) =>
      setState(() => _skills = _skills.where((e) => e != s).toList());

  bool get _canSave => !_saving && _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    // Dựng từ bản gốc rồi chèn đè. Thứ tự này là điểm mấu chốt của cả màn.
    final payload = Map<String, dynamic>.from(_me.raw)
      ..['name'] = _name.text.trim()
      ..['headline'] = _headline.text.trim()
      ..['school'] = _school.text.trim()
      ..['location'] = _location.text.trim()
      ..['bio'] = _bio.text.trim()
      ..['skills'] = _skills
      ..['openToWork'] = _openToWork;

    // Các trường CHỈ ĐỌC của phản hồi. Backend không đọc chúng trong
    // PortfolioRequest, nhưng gửi kèm thì payload phình vô ích — avatarUrl và
    // coverBannerUrl có thể là data URL base64 dài hàng trăm KB.
    for (final k in const [
      'avatarUrl',
      'publicSlug',
      'onboardingCompleted',
      'reputationScore',
      'totalExp',
      'currentLevel',
      'npBalance',
      'selectedTheme',
      'themeUnlocked',
      'legalConsentVersion',
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

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    // Gợi ý: lọc theo chữ đang gõ, bỏ những cái đã chọn. Chỉ lấy 8 — danh sách
    // dài hơn thì đẩy ô nhập lên khỏi màn hình khi bàn phím đang mở.
    final q = _skillInput.text.trim().toLowerCase();
    final suggestions = q.isEmpty
        ? const <String>[]
        : _catalog
            .where((s) => s.toLowerCase().contains(q) && !_has(s))
            .take(8)
            .toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Sửa hồ sơ', style: NpType.h1.copyWith(color: c.ink)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Np.gutter),
            child: GestureDetector(
              onTap: _canSave ? _save : null,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Text(_saving ? 'Đang lưu…' : 'Lưu',
                    style: NpType.button.copyWith(
                      fontSize: 15,
                      color: _canSave ? c.acidText : c.faint,
                    )),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Np.gutter, Np.s2, Np.gutter,
            Np.s10 + MediaQuery.viewInsetsOf(context).bottom),
        children: [
          _Field(
            label: 'Họ và tên',
            controller: _name,
            hint: 'Nguyễn Văn A',
            onChanged: (_) => setState(() {}),
            // Trường DUY NHẤT bắt buộc (@NotBlank ở PortfolioRequest). Nói ra
            // ngay dưới ô thay vì để người dùng bấm Lưu rồi mới nhận lỗi.
            note: _name.text.trim().isEmpty ? 'Không được để trống' : null,
          ),
          _Field(
            label: 'Giới thiệu ngắn',
            controller: _headline,
            hint: 'Sinh viên Hệ thống thông tin, thích làm sản phẩm',
          ),
          _Field(label: 'Trường', controller: _school, hint: 'FPTU HCM'),
          _Field(
              label: 'Nơi ở', controller: _location, hint: 'TP. Hồ Chí Minh'),
          _Field(
            label: 'Mô tả bản thân',
            controller: _bio,
            hint: 'Vài dòng về bạn, dự án đã làm, thứ đang muốn học…',
            lines: 5,
          ),

          const SizedBox(height: Np.s2),
          _OpenToWork(
            value: _openToWork,
            onChanged: (v) => setState(() => _openToWork = v),
          ),

          const SizedBox(height: Np.s6),
          const SectionLabel('Kỹ năng'),
          const SizedBox(height: Np.s2),
          Text(
            'App dùng kỹ năng để tìm việc hợp với bạn. Chưa có kỹ năng nào thì '
            'trang chủ chỉ gợi ý được theo hạn nộp.',
            style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted),
          ),
          const SizedBox(height: Np.s4),

          if (_skills.isNotEmpty) ...[
            Wrap(
              spacing: Np.s2,
              runSpacing: Np.s2,
              children: [
                for (final s in _skills)
                  _SkillChip(label: s, onRemove: () => _removeSkill(s)),
              ],
            ),
            const SizedBox(height: Np.s4),
          ],

          TextField(
            controller: _skillInput,
            style: NpType.body.copyWith(color: c.ink),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: _addSkill,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: Np.s4, vertical: Np.s3 + 2),
              hintText: 'Gõ tên kỹ năng rồi Enter',
              hintStyle: NpType.body.copyWith(color: c.faint),
              filled: true,
              fillColor: c.surface,
              suffixIcon: _skillInput.text.trim().isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () => _addSkill(_skillInput.text),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(right: Np.s3),
                        child: Center(
                          widthFactor: 1,
                          child: Text('Thêm',
                              style: NpType.meta.copyWith(
                                color: c.acidText,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ),
                    ),
              border: _border(c, c.line),
              enabledBorder: _border(c, c.line),
              focusedBorder: _border(c, c.acid),
            ),
          ),

          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: Np.s3),
            Wrap(
              spacing: Np.s2,
              runSpacing: Np.s2,
              children: [
                for (final s in suggestions)
                  GestureDetector(
                    onTap: () => _addSkill(s),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Np.s3 + 2, vertical: Np.s2),
                      decoration: BoxDecoration(
                        color: c.surfaceHi,
                        borderRadius: BorderRadius.circular(Np.rPill),
                        border: Border.all(color: c.line),
                      ),
                      child: Text(s,
                          style: NpType.meta
                              .copyWith(fontSize: 13, color: c.ink)),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: Np.s8),
          Text(
            'Kinh nghiệm và chứng chỉ vẫn sửa trên website — chúng cần tải ảnh '
            'minh chứng và đi qua bước xác thực. Lưu ở đây KHÔNG làm mất chúng.',
            style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(NpColors c, Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Np.rMd),
        borderSide: BorderSide(color: color),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.lines = 1,
    this.note,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int lines;
  final String? note;
  final ValueChanged<String>? onChanged;

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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Np.rMd),
                borderSide: BorderSide(color: c.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Np.rMd),
                borderSide: BorderSide(
                    color: note == null ? c.line : c.danger.withValues(alpha: 0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Np.rMd),
                borderSide: BorderSide(color: note == null ? c.acid : c.danger),
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: Np.s1 + 2),
            Text(note!,
                style: NpType.meta.copyWith(fontSize: 12, color: c.danger)),
          ],
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.only(left: Np.s3 + 2, right: Np.s2),
      height: 34,
      decoration: BoxDecoration(
        color: c.acid.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Np.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: NpType.meta.copyWith(
                fontSize: 13,
                color: c.acidText,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: Np.s1),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            // Vùng chạm 28px cho một dấu × cao 11px: nhỏ hơn thì bấm trượt
            // sang chip bên cạnh và xoá nhầm.
            child: SizedBox(
              width: 28,
              height: 34,
              child: Icon(Icons.close_rounded, size: 15, color: c.acidText),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenToWork extends StatelessWidget {
  const _OpenToWork({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s3 + 2),
        decoration: Np.card(c, radius: Np.rMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đang tìm việc',
                      style: NpType.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text('Hiện dấu Open to Work trên hồ sơ công khai',
                      style: NpType.meta
                          .copyWith(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: c.onAcid,
              activeTrackColor: c.acid,
            ),
          ],
        ),
      ),
    );
  }
}
