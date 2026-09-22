import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../jobs/opportunity_labels.dart';
import 'credential.dart';
import 'credentials_store.dart';
import 'submit_credential_page.dart';

/// Danh sách minh chứng đã nộp và trạng thái duyệt của từng cái.
class CredentialsPage extends StatefulWidget {
  const CredentialsPage({super.key});

  @override
  State<CredentialsPage> createState() => _CredentialsPageState();
}

class _CredentialsPageState extends State<CredentialsPage> {
  final _store = CredentialsStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_sync);
    _store.hydrate();
  }

  @override
  void dispose() {
    _store.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubmitCredentialPage()),
    );
    // Kho đã tự nạp lại sau khi nộp và báo qua listener; không gọi thêm ở đây
    // để khỏi tốn một lượt gọi mạng thừa.
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final items = _store.items;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Minh chứng', style: NpType.h1.copyWith(color: c.ink)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Np.gutter),
            child: GestureDetector(
              onTap: _submit,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Text('Nộp mới',
                    style: NpType.button
                        .copyWith(fontSize: 15, color: c.acidText)),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _store.hydrate,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    Np.gutter, Np.s10, Np.gutter, Np.s10),
                children: [
                  NpIco(NpIcon.bolt, size: 26, color: c.faint),
                  const SizedBox(height: Np.s4),
                  Text(
                    _store.loaded
                        ? 'Chưa có minh chứng nào'
                        : 'Đang tải…',
                    style: NpType.title.copyWith(fontSize: 17, color: c.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Np.s2),
                  Text(
                    'Nộp một hoạt động bạn đã làm kèm bằng chứng. Được duyệt '
                    'thì nó cộng EXP, điểm uy tín và gắn dấu đã xác thực trên '
                    'hồ sơ của bạn.',
                    style: NpType.meta.copyWith(color: c.muted, height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Np.s6),
                  Center(
                    child: AcidButton(
                        label: 'Nộp minh chứng',
                        onTap: _submit,
                        expand: false),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    Np.gutter, Np.s2, Np.gutter, Np.s10),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Np.s3),
                itemBuilder: (_, i) => _Card(item: items[i]),
              ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item});
  final Credential item;

  /// Ba mức màu, không phải bốn: "Cần bổ sung" và "Bị từ chối" đều là việc
  /// người dùng phải làm gì đó, nên cùng một màu cảnh báo. Tô mỗi trạng thái
  /// một màu riêng thì danh sách thành bảng cầu vồng và không mức nào nổi.
  Color _tint(NpColors c) => switch (item.status) {
        'APPROVED' => c.acidText,
        'REJECTED' || 'NEEDS_MORE_EVIDENCE' => c.danger,
        _ => c.muted,
      };

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final tint = _tint(c);

    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(item.projectName,
                    style: NpType.title.copyWith(fontSize: 16, color: c.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: Np.s3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s2 + 2, vertical: 3),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(Np.rPill),
                ),
                child: Text(credentialStatusLabel(item.status),
                    style: NpType.meta.copyWith(
                      fontSize: 11.5,
                      color: tint,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              if (item.position.isNotEmpty) item.position,
              categoryLabel(item.category),
              roleLevelLabel(item.roleLevel),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: NpType.meta.copyWith(fontSize: 12, color: c.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (item.proofImages.isNotEmpty) ...[
            const SizedBox(height: Np.s3),
            Row(
              children: [
                NpIco(NpIcon.search, size: 14, color: c.faint),
                const SizedBox(width: Np.s2),
                Text('${item.proofImages.length} ảnh minh chứng',
                    style: NpType.meta.copyWith(fontSize: 12, color: c.faint)),
              ],
            ),
          ],

          // Lý do từ chối là thứ người dùng THẬT SỰ cần đọc khi thấy nhãn đỏ.
          // Giấu nó đi và chỉ hiện chữ "Bị từ chối" là chắc chắn làm họ bực
          // mà không biết phải sửa gì.
          if (item.rejectReason != null && item.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: Np.s3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Np.s3),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Np.rSm),
              ),
              child: Text(item.rejectReason!,
                  style: NpType.meta.copyWith(fontSize: 12.5, color: c.ink)),
            ),
          ],

          if (item.createdAt != null) ...[
            const SizedBox(height: Np.s3),
            Text('Nộp ${dmy(item.createdAt)}',
                style: NpType.meta.copyWith(fontSize: 11.5, color: c.faint)),
          ],
        ],
      ),
    );
  }
}
