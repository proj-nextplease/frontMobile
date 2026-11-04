import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/applied_store.dart';
import '../jobs/opportunity_labels.dart';
import '../wallet/topup_sheet.dart';
import '../wallet/wallet_store.dart';
import 'application_item.dart';

/// Lời mời đang chờ ứng viên trả lời: lời mời nhận việc (đơn ở trạng thái
/// OFFERED) và lời mời gia nhập tổ chức/CLB.
///
/// Bản web đặt khối này đầu trang Tổng quan ("Cơ hội đang chờ bạn phản
/// hồi"). App trước giờ không đọc hai thứ này, nên một ứng viên dùng điện
/// thoại được mời nhận việc mà không có cách nào bấm đồng ý — lời mời cứ nằm
/// đó tới khi hết hạn.
///
/// Khối tự nạp dữ liệu và tự ẩn khi không có gì, nên nơi gắn nó chỉ cần đặt
/// vào chứ không phải lo trạng thái rỗng.
class PendingInvitesSection extends StatefulWidget {
  const PendingInvitesSection({
    super.key,
    this.refreshToken = 0,
    this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: Np.gutter),
    this.topGap = Np.s6,
  });

  /// Đổi giá trị này để buộc khối nạp lại (vd khi trang cha kéo-để-tải-lại).
  final int refreshToken;

  /// Gọi sau khi người dùng nhận/từ chối, để trang cha nạp lại phần của nó.
  final VoidCallback? onChanged;
  final EdgeInsets padding;

  /// Khoảng trống phía trên, chỉ áp khi khối thật sự hiện.
  final double topGap;

  @override
  State<PendingInvitesSection> createState() => _PendingInvitesSectionState();
}

class _PendingInvitesSectionState extends State<PendingInvitesSection> {
  final _api = ApiClient();
  List<ApplicationItem> _offers = const [];
  List<Map<String, dynamic>> _orgInvites = const [];
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PendingInvitesSection old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final res = await Future.wait([
      _try('/me/applications'),
      _try('/company/my-pending-invitations'),
    ]);
    if (!mounted) return;
    setState(() {
      _offers = (res[0] ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ApplicationItem.fromJob)
          .where((a) => a.isOffer)
          .toList();
      _orgInvites =
          (res[1] ?? const []).whereType<Map<String, dynamic>>().toList();
    });
  }

  Future<List<dynamic>?> _try(String path) async {
    try {
      final d = await _api.get(path);
      return d is List ? d : const [];
    } on ApiException {
      return null;
    }
  }

  Future<void> _accept(ApplicationItem app) async {
    setState(() => _busyId = app.id);
    final ok = await OfferActions.accept(context, app);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (ok) {
      await _load();
      widget.onChanged?.call();
    }
  }

  Future<void> _decline(ApplicationItem app) async {
    setState(() => _busyId = app.id);
    final ok = await OfferActions.decline(context, app);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (ok) {
      await _load();
      widget.onChanged?.call();
    }
  }

  Future<void> _joinOrg(Map<String, dynamic> invite) async {
    final id = '${invite['id']}';
    setState(() => _busyId = id);
    String? err;
    Object? res;
    try {
      res = await _api.post('/company/invitations/$id/accept-direct');
    } on ApiException catch (e) {
      err = e.message;
    }
    if (!mounted) return;
    setState(() => _busyId = null);
    final name = (res is Map ? res['companyName'] : null) ??
        invite['companyName'] ??
        'tổ chức';
    npToast(context, err ?? 'Đã gia nhập $name.', ok: err == null);
    if (err == null) {
      setState(() => _orgInvites =
          _orgInvites.where((i) => '${i['id']}' != id).toList());
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _offers.length + _orgInvites.length;
    if (total == 0) return const SizedBox.shrink();
    final c = Np.of(context);

    return Padding(
      padding: widget.padding.copyWith(top: widget.topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.acid.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Np.rPill),
                ),
                child: Text('Lời mời mới · $total',
                    style: NpType.meta.copyWith(
                      fontSize: 12,
                      color: c.acidText,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              const SizedBox(width: Np.s3),
              Expanded(
                child: Text('Đang chờ bạn phản hồi',
                    style: NpType.title.copyWith(color: c.ink)),
              ),
            ],
          ),
          const SizedBox(height: Np.s3),
          for (final app in _offers) ...[
            OfferCard(
              item: app,
              busy: _busyId == app.id,
              onAccept: () => _accept(app),
              onDecline: () => _decline(app),
            ),
            const SizedBox(height: Np.s3),
          ],
          for (final inv in _orgInvites) ...[
            _OrgInviteCard(
              invite: inv,
              busy: _busyId == '${inv['id']}',
              onAccept: () => _joinOrg(inv),
            ),
            const SizedBox(height: Np.s3),
          ],
        ],
      ),
    );
  }
}

/// Nhận / từ chối offer. Dùng chung cho khối lời mời và màn chi tiết đơn.
///
/// Trả về true khi thao tác thành công.
class OfferActions {
  static final _api = ApiClient();

  static Future<bool> accept(BuildContext context, ApplicationItem app) async {
    final w = WalletStore.instance;
    final fee = app.isPaid ? w.jobAcceptanceFeeNp : 0;

    // Kiểm số dư TRƯỚC khi gọi: để máy chủ trả 402 rồi mới báo thì người
    // dùng đã bấm xác nhận một lần vô ích.
    if (fee > 0 && w.loaded && w.balance < fee) {
      npToast(
        context,
        'Số dư ${WalletStore.money(w.balance)} NP không đủ trả phí nhận việc '
        '${WalletStore.money(fee)} NP. Nạp thêm để tiếp tục.',
        ok: false,
      );
      await TopUpSheet.show(context);
      return false;
    }

    final ok = await _confirm(
      context,
      title: 'Đồng ý nhận việc?',
      body: fee > 0
          ? 'Bạn xác nhận nhận "${app.title}" tại ${app.companyName}. '
              'Trừ ${WalletStore.money(fee)} NP phí xác nhận — chỉ trừ khi '
              'xác nhận thành công.'
          : 'Bạn xác nhận nhận "${app.title}" tại ${app.companyName}. '
              'Vị trí không thù lao nên miễn phí.',
      action: 'Đồng ý nhận việc',
      danger: false,
    );
    if (ok != true || !context.mounted) return false;

    String? err;
    try {
      await _api.post(app.acceptOfferPath);
    } on ApiException catch (e) {
      err = e.message;
    }
    if (!context.mounted) return false;
    npToast(
      context,
      err ??
          (fee > 0
              ? 'Chúc mừng! Bạn đã nhận việc (trừ ${WalletStore.money(fee)} NP).'
              : 'Chúc mừng! Bạn đã nhận việc.'),
      ok: err == null,
    );
    if (err == null) {
      // Số dư vừa đổi và đơn vừa đổi trạng thái — nạp lại cả hai.
      await Future.wait([w.hydrate(), AppliedStore.instance.hydrate()]);
    }
    return err == null;
  }

  static Future<bool> decline(BuildContext context, ApplicationItem app) async {
    final ok = await _confirm(
      context,
      title: 'Từ chối lời mời?',
      body: 'Bạn sẽ từ chối lời mời nhận "${app.title}". '
          'Thao tác này không hoàn tác được.',
      action: 'Từ chối',
      danger: true,
    );
    if (ok != true || !context.mounted) return false;

    String? err;
    try {
      await _api.post(app.declineOfferPath, body: {'reason': ''});
    } on ApiException catch (e) {
      err = e.message;
    }
    if (!context.mounted) return false;
    npToast(context, err ?? 'Bạn đã từ chối lời mời nhận việc.',
        ok: err == null);
    return err == null;
  }

  static Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required bool danger,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) {
          final c = Np.of(ctx);
          return AlertDialog(
            backgroundColor: c.surfaceHi,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Np.rLg)),
            title: Text(title, style: NpType.h1.copyWith(color: c.ink)),
            content: Text(body, style: NpType.meta.copyWith(color: c.muted)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child:
                    Text('Huỷ', style: NpType.button.copyWith(color: c.muted)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(action,
                    style: NpType.button
                        .copyWith(color: danger ? c.danger : c.acidText)),
              ),
            ],
          );
        },
      );
}

/// Thẻ một lời mời nhận việc.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.item,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    this.onOpen,
  });

  final ApplicationItem item;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final fee = WalletStore.instance.jobAcceptanceFeeNp;

    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(Np.s4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Np.rLg),
          border: Border.all(color: c.acid.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NpIco(NpIcon.company, size: 15, color: c.acidText),
                const SizedBox(width: Np.s2),
                Expanded(
                  child: Text(
                    item.companyName.isEmpty ? 'Doanh nghiệp' : item.companyName,
                    style: NpType.meta.copyWith(
                        color: c.ink, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const MetaChip(label: 'Mời nhận việc', accent: true),
              ],
            ),
            const SizedBox(height: Np.s2),
            Text(item.title,
                style: NpType.title.copyWith(fontSize: 18, color: c.ink)),
            const SizedBox(height: Np.s2),
            Text(
              item.isPaid
                  ? 'Thù lao ${salaryLabel(compensation: item.compensation, isQuest: false)}'
                      ' · Phí xác nhận ${WalletStore.money(fee)} NP'
                      ' (chỉ trừ khi đồng ý thành công)'
                  : 'Vị trí không thù lao · Miễn phí khi xác nhận nhận việc',
              style: NpType.meta.copyWith(fontSize: 13, color: c.muted),
            ),
            const SizedBox(height: Np.s4),
            Row(
              children: [
                Expanded(
                  child: AcidButton(
                    label: item.isPaid
                        ? 'Đồng ý · ${WalletStore.money(fee)} NP'
                        : 'Đồng ý nhận việc',
                    busy: busy,
                    onTap: onAccept,
                  ),
                ),
                const SizedBox(width: Np.s3),
                GestureDetector(
                  onTap: busy ? null : onDecline,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: Np.s4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Np.rPill),
                      border:
                          Border.all(color: c.danger.withValues(alpha: 0.4)),
                    ),
                    child: Text('Từ chối',
                        style: NpType.button.copyWith(color: c.danger)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrgInviteCard extends StatelessWidget {
  const _OrgInviteCard({
    required this.invite,
    required this.busy,
    required this.onAccept,
  });

  final Map<String, dynamic> invite;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final isClub = invite['companyType'] == 'CLUB';
    final role = switch (invite['nodeRole']) {
      'OWNER' => 'Chủ sở hữu',
      'MANAGER' => 'Quản lý',
      _ => 'Thành viên',
    };
    final logo = invite['companyLogo'];

    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CompanyLogo(
                url: logo is String ? logo : null,
                name: '${invite['companyName'] ?? ''}',
                size: 36,
              ),
              const SizedBox(width: Np.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${invite['companyName'] ?? 'Tổ chức'}',
                        style: NpType.title.copyWith(fontSize: 16, color: c.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(isClub ? 'Câu lạc bộ' : 'Doanh nghiệp',
                        style: NpType.meta.copyWith(fontSize: 12, color: c.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Np.s3),
          Text('Bạn được mời gia nhập với vai trò $role.',
              style: NpType.meta.copyWith(fontSize: 13, color: c.muted)),
          const SizedBox(height: Np.s4),
          AcidButton(
            label: 'Chấp nhận gia nhập',
            busy: busy,
            onTap: onAccept,
          ),
        ],
      ),
    );
  }
}

/// Thông báo nổi ngắn, cùng kiểu với các màn khác trong app.
void npToast(BuildContext context, String msg, {required bool ok}) {
  final c = Np.of(context);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: ok ? c.surfaceHi : c.danger,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
    content: Text(msg,
        style: NpType.body
            .copyWith(fontSize: 14, color: ok ? c.ink : Colors.white)),
  ));
}
