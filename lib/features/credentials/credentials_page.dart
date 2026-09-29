import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../jobs/opportunity_labels.dart';
import '../wallet/wallet_store.dart';
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
  /// Id minh chứng đang xử lý duyệt nhanh. Null là không có cái nào.
  String? _expressBusyId;

  Future<void> _express(Credential item) async {
    final w = WalletStore.instance;
    final price = w.prices['expressPriceNp'] ?? 0;

    if (w.balance < price) {
      _toast('Bạn còn thiếu ${price - w.balance} NP để duyệt nhanh.', ok: false);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = Np.of(ctx);
        return AlertDialog(
          backgroundColor: c.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rLg)),
          title: Text('Duyệt nhanh minh chứng này?',
              style: NpType.title.copyWith(color: c.ink)),
          content: Text(
              '"${item.projectName}" sẽ được xếp lên trước hàng chờ thẩm định. '
              'Trừ $price NP.\n\n'
              'Nếu minh chứng bị từ chối, phí này được hoàn lại vào ví.',
              style: NpType.body.copyWith(color: c.muted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Huỷ', style: NpType.button.copyWith(color: c.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Duyệt nhanh',
                  style: NpType.button.copyWith(color: c.acidText)),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    setState(() => _expressBusyId = item.id);
    final err = await WalletStore.instance.expressVerification(item.id);
    if (!mounted) return;

    /* Nạp lại danh sách để cờ `express` về từ máy chủ, thay vì tự sửa trong
       bộ nhớ. Tự sửa thì màn hình nói đã mua trong khi thực tế còn phụ thuộc
       vào việc backend ghi được hay không. */
    if (err == null) await CredentialsStore.instance.hydrate();
    if (!mounted) return;
    setState(() => _expressBusyId = null);
    _toast(err ?? 'Đã đăng ký duyệt nhanh.', ok: err == null);
  }

  void _toast(String msg, {required bool ok}) {
    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? c.surfaceHi : c.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
      content: Text(msg,
          style: NpType.body.copyWith(
              fontSize: 14, color: ok ? c.ink : Colors.white)),
    ));
  }

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
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NeonMeshBackground(height: 380),
          ),
          RefreshIndicator(
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
                    _store.error != null
                        ? 'Không tải được minh chứng'
                        : _store.loaded
                            ? 'Chưa có minh chứng nào'
                            : 'Đang tải…',
                    style: NpType.title.copyWith(fontSize: 17, color: c.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Np.s2),
                  // "Chưa có gì" và "tải hỏng" là hai chuyện khác nhau và phải
                  // nói khác nhau — nếu không, mạng chập một cái là app khẳng
                  // định người dùng chưa từng nộp minh chứng nào.
                  Text(
                    _store.error ??
                        'Nộp một hoạt động bạn đã làm kèm bằng chứng. Được '
                            'duyệt thì nó cộng EXP, điểm uy tín và gắn dấu đã '
                            'xác thực trên hồ sơ của bạn.',
                    style: NpType.meta.copyWith(color: c.muted, height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                  if (_store.error != null) ...[
                    const SizedBox(height: Np.s4),
                    Center(
                      child: GestureDetector(
                        onTap: _store.hydrate,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(Np.s2),
                          child: Text('Thử lại',
                              style: NpType.button
                                  .copyWith(fontSize: 15, color: c.acidText)),
                        ),
                      ),
                    ),
                  ],
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
                itemBuilder: (_, i) => _Card(
                  item: items[i],
                  busy: _expressBusyId == items[i].id,
                  onExpress: () => _express(items[i]),
                ),
              ),
        ),
      ],
    ),
  );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.onExpress, this.busy = false});
  final Credential item;
  final VoidCallback onExpress;
  final bool busy;

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
    final expressPrice = WalletStore.instance.prices['expressPriceNp'];

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

          /* Duyệt nhanh chỉ có nghĩa với minh chứng ĐANG CHỜ. Đã duyệt thì
             không còn gì để đẩy nhanh, bị từ chối thì trả tiền cũng vô ích —
             backend cũng từ chối đúng như vậy, nên hiện nút ở đó chỉ dẫn
             người dùng tới một thông báo lỗi. */
          if (item.status == 'PENDING') ...[
            const SizedBox(height: Np.s3),
            if (item.express)
              Row(
                children: [
                  NpIco(NpIcon.bolt, size: 14, color: c.acidText),
                  const SizedBox(width: Np.s2),
                  Text('Đang được duyệt nhanh',
                      style: NpType.meta.copyWith(
                          fontSize: 12,
                          color: c.acidText,
                          fontWeight: FontWeight.w600)),
                ],
              )
            else
              GestureDetector(
                onTap: busy ? null : onExpress,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: Np.s3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Np.rPill),
                    border: Border.all(color: c.acid),
                  ),
                  child: Text(
                    busy
                        ? '…'
                        : 'Duyệt nhanh 24h'
                            '${expressPrice == null ? '' : ' · $expressPrice NP'}',
                    style: NpType.button.copyWith(
                        fontSize: 13.5, color: c.acidText),
                  ),
                ),
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
