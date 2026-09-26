import 'package:flutter/material.dart';

import '../../core/mascot.dart';
import '../../core/theme.dart';
import 'edit_profile_page.dart';
import 'edit_experience_page.dart';
import 'me_store.dart';

/// Hồ sơ năng lực — CHỈ ĐỌC.
///
/// Phần soạn thảo (thêm kinh nghiệm, tải chứng chỉ, đính kèm ảnh minh chứng)
/// là một trình soạn nhiều bước và hiện chỉ có trên website. Nhưng "chưa sửa
/// được trong app" không phải lý do để không CHO XEM: người dùng cần biết hồ
/// sơ mình đang trông ra sao trước khi quyết định có mở máy tính lên hay
/// không, và trang chủ thì đang nhắc họ bổ sung.
class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  final _me = MeStore.instance;

  @override
  void initState() {
    super.initState();
    _me.addListener(_sync);
    if (!_me.loaded) _me.hydrate();
  }

  @override
  void dispose() {
    _me.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    // EditProfilePage đã gọi hydrate() sau khi lưu, và kho báo qua listener.
    // Không cần nạp lại ở đây — làm vậy chỉ thêm một lượt gọi mạng thừa.
  }

  /// Các liên kết đã điền, bỏ qua giá trị rỗng.
  Map<String, String> get _socialLinks {
    final raw = _me.raw['socialLinks'];
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if ('${e.value}'.trim().isNotEmpty) '${e.key}': '${e.value}'.trim(),
    };
  }

  static String _socialLabel(String key) => switch (key) {
        'github' => 'GitHub',
        'linkedin' => 'LinkedIn',
        'website' => 'Website',
        'email' => 'Email',
        _ => key,
      };

  Future<void> _editExperience() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditExperiencePage()),
    );
    // MeStore đã tự nạp lại sau khi lưu và báo qua listener; setState ở đây chỉ
    // để chắc chắn khi người dùng thoát mà không lưu.
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final missing = _me.missing;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Hồ sơ năng lực', style: NpType.h1.copyWith(color: c.ink)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Np.gutter),
            child: GestureDetector(
              onTap: _edit,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Text('Sửa',
                    style: NpType.button
                        .copyWith(fontSize: 15, color: c.acidText)),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _me.hydrate,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              Np.gutter, Np.s2, Np.gutter, Np.s10),
          children: [
            _Completeness(
              value: _me.completeness,
              missing: missing,
              avatar: _me.raw['avatar'],
            ),
            const SizedBox(height: Np.s6),

            if (_me.headline != null) ...[
              _Section(label: 'Giới thiệu'),
              Text(_me.headline!,
                  style: NpType.body.copyWith(color: c.ink)),
              if (_me.bio != null) ...[
                const SizedBox(height: Np.s2),
                Text(_me.bio!, style: NpType.meta.copyWith(color: c.muted)),
              ],
              const SizedBox(height: Np.s6),
            ],

            if (_me.school != null) ...[
              _Section(label: 'Trường'),
              Text(_me.school!, style: NpType.body.copyWith(color: c.ink)),
              const SizedBox(height: Np.s6),
            ],

            _Section(label: 'Kỹ năng'),
            if (_me.skills.isEmpty)
              _Hint(
                text: 'Chưa có kỹ năng nào. Đây là thứ app dùng để tìm việc '
                    'hợp với bạn, nên thiếu nó thì trang chủ chỉ gợi ý được '
                    'theo hạn nộp.',
              )
            else
              Wrap(
                spacing: Np.s2,
                runSpacing: Np.s2,
                children: [
                  // skillLabels giữ ĐÚNG chữ người dùng đã nhập. Bản trước lấy
                  // từ `skills` (đã hạ chữ thường để so khớp) rồi viết hoa lại
                  // chữ đầu, nên "JavaScript" ra "Javascript" và "SQL" ra
                  // "Sql" — sai tên riêng của chính công nghệ đó.
                  for (final s in _me.skillLabels) _Chip(label: s),
                ],
              ),
            const SizedBox(height: Np.s6),

            // Hiện lại ngay trong app, không chỉ trên trang công khai: sửa
            // được mà không thấy kết quả thì người dùng không biết mình đã gõ
            // đúng chưa.
            if (_socialLinks.isNotEmpty) ...[
              _Section(label: 'Liên kết'),
              Wrap(
                spacing: Np.s2,
                runSpacing: Np.s2,
                children: [
                  for (final e in _socialLinks.entries)
                    _Chip(label: '${_socialLabel(e.key)}: ${e.value}'),
                ],
              ),
              const SizedBox(height: Np.s6),
            ],

            Row(
              children: [
                Expanded(child: _Section(label: 'Kinh nghiệm')),
                GestureDetector(
                  onTap: _editExperience,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Np.s1),
                    child: Text(
                      _me.experienceList.isEmpty ? 'Thêm' : 'Sửa',
                      style: NpType.button
                          .copyWith(fontSize: 14, color: c.acidText),
                    ),
                  ),
                ),
              ],
            ),
            if (_me.experienceList.isEmpty)
              _Hint(text: 'Chưa có mục kinh nghiệm nào.')
            else
              for (final e in _me.experienceList) ...[
                _ExperienceRow(item: e),
                const SizedBox(height: Np.s2),
              ],
            const SizedBox(height: Np.s6),

            _Section(label: 'Chứng chỉ'),
            if (_me.credentialList.isEmpty)
              _Hint(text: 'Chưa có chứng chỉ nào.')
            else
              for (final cr in _me.credentialList) ...[
                _CredentialRow(item: cr),
                const SizedBox(height: Np.s2),
              ],

            const SizedBox(height: Np.s8),
            // Câu cũ ghi "kinh nghiệm và chứng chỉ cần tải ảnh minh chứng"
            // — sai với phần kinh nghiệm: ExperienceDto toàn là chữ, proofLink
            // chỉ là một URL. App đang đổ lỗi cho một ràng buộc không tồn tại.
            _Hint(
              text: 'Chứng chỉ và ảnh bìa vẫn sửa trên website — chứng chỉ cần '
                  'tải tệp bằng cấp lên.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Thanh hoàn thiện. Con số đi kèm DANH SÁCH còn thiếu — một phần trăm trần
/// trụi chỉ làm người ta lo mà không biết phải làm gì tiếp.
class _Completeness extends StatelessWidget {
  const _Completeness({
    required this.value,
    required this.missing,
    required this.avatar,
  });

  final double value;
  final List<String> missing;
  final dynamic avatar;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final pct = (value * 100).round();
    final mascotId = NpMascot.resolveId(avatar);

    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: Np.card(c, radius: Np.rLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Hồ sơ hoàn thiện $pct%',
                        style: NpType.title.copyWith(fontSize: 16.5, color: c.ink)),
                  ],
                ),
                const SizedBox(height: Np.s3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Np.rPill),
                  child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: c.line,
                    valueColor: AlwaysStoppedAnimation(c.acid),
                  ),
                ),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: Np.s3),
                  Text('Còn thiếu: ${missing.join(', ')}',
                      style: NpType.meta.copyWith(fontSize: 12, color: c.muted)),
                ] else ...[
                  const SizedBox(height: Np.s3),
                  Text('Tuyệt vời! Hồ sơ đã hoàn tất.',
                      style: NpType.meta.copyWith(
                        fontSize: 12,
                        color: c.acidText,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(width: Np.s3),
          InteractiveMascot(
            mascotId: mascotId,
            size: 78,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Np.s3),
      child: Text(label, style: NpType.label.copyWith(color: c.muted)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Np.s3 + 2, vertical: Np.s2),
      decoration: BoxDecoration(
        color: c.acid.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Np.rPill),
      ),
      child: Text(label,
          style: NpType.meta.copyWith(
            fontSize: 13,
            color: c.acidText,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Text(text, style: NpType.meta.copyWith(color: c.muted));
  }
}

class _ExperienceRow extends StatelessWidget {
  const _ExperienceRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final title = '${item['title'] ?? ''}'.trim();
    final org = '${item['organization'] ?? ''}'.trim();
    final from = '${item['startDate'] ?? ''}'.trim();
    final to = '${item['endDate'] ?? ''}'.trim();
    final verified = item['verified'] == true;

    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title.isEmpty ? 'Kinh nghiệm' : title,
                    style: NpType.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              // Dấu đã kiểm chứng là điểm khác biệt của sản phẩm này so với
              // một bản CV tự khai, nên nó phải nhìn thấy được.
              if (verified) ...[
                const SizedBox(width: Np.s2),
                NpIco(NpIcon.bolt, size: 15, color: c.acidText),
              ],
            ],
          ),
          if (org.isNotEmpty || from.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              [
                if (org.isNotEmpty) org,
                if (from.isNotEmpty) '$from — ${to.isEmpty ? 'nay' : to}',
              ].join(' · '),
              style: NpType.meta.copyWith(fontSize: 12, color: c.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final name = '${item['name'] ?? ''}'.trim();
    final issuer = '${item['issuer'] ?? ''}'.trim();
    final at = '${item['issuedAt'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.isEmpty ? 'Chứng chỉ' : name,
              style: NpType.body
                  .copyWith(color: c.ink, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (issuer.isNotEmpty || at.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text([if (issuer.isNotEmpty) issuer, if (at.isNotEmpty) at].join(' · '),
                style: NpType.meta.copyWith(fontSize: 12, color: c.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
