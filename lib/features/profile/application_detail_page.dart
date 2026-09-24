import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/applied_store.dart';
import '../jobs/opportunity_labels.dart';
import '../wallet/wallet_store.dart';
import 'application_item.dart';
import 'rating_view.dart';

/// Chi tiết một đơn đã nộp.
///
/// ─── Vì sao màn này cần có ───────────────────────────────────────────────
/// Nộp xong, app hiện một dòng "Đã nộp đơn. Tổ chức sẽ phản hồi qua thông
/// báo" rồi thôi. Người dùng không xem lại được mình đã viết gì, không biết
/// nhà tuyển dụng đã mở đơn chưa, và không rút lại được.
///
/// Dữ liệu cho tất cả những thứ đó đã nằm sẵn trong payload của
/// /me/applications (cover_note, statusHistory) và endpoint rút đơn cũng đã
/// có — chỉ là chưa ai hiện ra.
class ApplicationDetailPage extends StatefulWidget {
  const ApplicationDetailPage({super.key, required this.item});
  final ApplicationItem item;

  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  final _api = ApiClient();
  late ApplicationItem _item = widget.item;
  bool _busy = false;

  /// Chỉ là trạng thái TRONG PHIÊN. /me/applications không trả về cờ đã-boost
  /// nên mở lại màn này sau đó, nút sẽ hiện lại. Sửa đúng phải làm ở backend;
  /// tới lúc đó thì ít nhất không mời người dùng trả tiền hai lần liên tiếp.
  bool _boosted = false;

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(title: _item.title),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    String? err;
    try {
      await _api.patch(_item.withdrawPath);
    } on ApiException catch (e) {
      err = e.message;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (err == null) {
      // Cập nhật tại chỗ rồi mới đóng: người dùng thấy trạng thái đổi thật
      // chứ không phải màn hình biến mất và phải tin là đã xong.
      setState(() => _item = _item.withStatus('WITHDRAWN'));
      // Rút rồi thì được nộp lại, nên phải gỡ khỏi kho đã-nộp — không thì nút
      // ứng tuyển ở tin đó vẫn kẹt ở "Đã nộp đơn".
      await AppliedStore.instance.hydrate();
    }

    if (!mounted) return;
    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: err == null ? c.surfaceHi : c.danger,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
        content: Text(err ?? 'Đã rút đơn.',
            style: NpType.body.copyWith(
              fontSize: 14,
              color: err == null ? c.ink : Colors.white,
            )),
      ),
    );
  }

  Future<void> _boost() async {
    final w = WalletStore.instance;
    final price = w.prices['boostPriceNp'] ?? 0;

    if (w.balance < price) {
      _toast('Bạn còn thiếu ${price - w.balance} NP để đẩy đơn này.',
          ok: false);
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
          title: Text('Đẩy đơn này?',
              style: NpType.title.copyWith(color: c.ink)),
          content: Text(
              'Đơn của bạn sẽ được xếp lên đầu danh sách của nhà tuyển dụng '
              'trong ${w.prices['boostDurationHours'] ?? '—'} giờ. Trừ $price NP.',
              style: NpType.body.copyWith(color: c.muted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child:
                  Text('Huỷ', style: NpType.button.copyWith(color: c.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Đẩy đơn',
                  style: NpType.button.copyWith(color: c.acidText)),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final err = await w.boost(_item.id, isQuest: _item.isQuest);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _boosted = err == null;
    });
    _toast(err ?? 'Đã đẩy đơn lên đầu danh sách.', ok: err == null);
  }

  void _toast(String msg, {required bool ok}) {
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

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final color = applicationStatusColor(_item.status, c);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Đơn của bạn', style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(Np.gutter, Np.s2, Np.gutter, Np.s10),
        children: [
          Text(_item.title,
              style: NpType.title.copyWith(fontSize: 20, color: c.ink)),
          const SizedBox(height: Np.s2),
          Text(
            [
              _item.companyName,
              if (_item.appliedAt != null) 'nộp ${dmy(_item.appliedAt)}',
            ].where((s) => s.isNotEmpty).join(' · '),
            style: NpType.meta.copyWith(color: c.muted),
          ),

          const SizedBox(height: Np.s5),
          Container(
            padding: const EdgeInsets.all(Np.s4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Np.rMd),
            ),
            child: Row(
              children: [
                NpIco(NpIcon.send, size: 17, color: color),
                const SizedBox(width: Np.s3),
                Expanded(
                  child: Text(_statusLine(),
                      style: NpType.meta.copyWith(
                          fontSize: 13.5, color: c.ink)),
                ),
              ],
            ),
          ),

          // Đánh giá đặt NGAY dưới trạng thái, trên cả dòng thời gian: đây
          // là thứ người dùng mở đơn để xem sau khi làm xong việc, không
          // phải một chi tiết phụ ở cuối trang.
          if (_item.ratingScore != null) ...[
            const SizedBox(height: Np.s5),
            const SectionLabel('Đánh giá của tổ chức'),
            const SizedBox(height: Np.s3),
            RatingCard(
              score: _item.ratingScore!,
              comment: _item.ratingComment,
              companyName: _item.companyName,
            ),
          ],

          if (_item.status == 'REJECTED' &&
              _item.rejectReason != null &&
              _item.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: Np.s6),
            const SectionLabel('Lý do từ chối'),
            const SizedBox(height: Np.s3),
            Text(_item.rejectReason!,
                style: NpType.body.copyWith(color: c.ink)),
          ],

          if (_item.history.isNotEmpty) ...[
            const SizedBox(height: Np.s6),
            const SectionLabel('Diễn biến'),
            const SizedBox(height: Np.s4),
            _Timeline(steps: _item.history),
          ],

          if (_item.coverNote != null && _item.coverNote!.isNotEmpty) ...[
            const SizedBox(height: Np.s6),
            const SectionLabel('Lời nhắn bạn đã gửi'),
            const SizedBox(height: Np.s3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Np.s4),
              decoration: Np.card(c, radius: Np.rMd),
              child: Text(_item.coverNote!,
                  style: NpType.body.copyWith(color: c.ink)),
            ),
          ],


          if (_item.canWithdraw) ...[
            const SizedBox(height: Np.s6),
            _BoostCard(
              boosted: _boosted,
              busy: _busy,
              onBoost: _boost,
            ),
          ],
          if (_item.canWithdraw) ...[
            const SizedBox(height: Np.s8),
            GestureDetector(
              onTap: _busy ? null : _withdraw,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(color: c.danger.withValues(alpha: 0.4)),
                ),
                child: Text(_busy ? 'Đang rút…' : 'Rút đơn',
                    style: NpType.button.copyWith(color: c.danger)),
              ),
            ),
            const SizedBox(height: Np.s3),
            Text(
              'Rút rồi vẫn nộp lại được, chừng nào tin còn hạn.',
              style: NpType.meta.copyWith(fontSize: 12, color: c.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Nói TRẠNG THÁI HIỆN TẠI NGHĨA LÀ GÌ, không chỉ lặp lại cái nhãn.
  ///
  /// "Đã nộp" là một từ; "nhà tuyển dụng chưa mở đơn" là một thông tin. Người
  /// đang chờ cần cái thứ hai.
  String _statusLine() => switch (_item.status) {
        'SUBMITTED' => 'Đơn đã gửi, nhà tuyển dụng chưa mở.',
        'VIEWED' => 'Nhà tuyển dụng đã mở đơn của bạn.',
        'SHORTLISTED' => 'Bạn đã vào vòng trong. Chờ liên hệ tiếp theo.',
        'ACCEPTED' => 'Bạn được nhận. Chúc mừng!',
        'REJECTED' => 'Đơn không được chọn lần này.',
        'WITHDRAWN' => 'Bạn đã rút đơn này.',
        'COMPLETED' => 'Công việc đã hoàn thành.',
        _ => applicationStatusLabel(_item.status),
      };
}

/// Dòng thời gian của đơn.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});
  final List<StatusStep> steps;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        // Mốc MỚI NHẤT được tô; các mốc cũ để nhạt. Tô hết thì
                        // không đọc ra được đơn đang ở đâu.
                        color: i == steps.length - 1 ? c.acid : c.line,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i != steps.length - 1)
                      Expanded(child: Container(width: 1.5, color: c.line)),
                  ],
                ),
                const SizedBox(width: Np.s3),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: i == steps.length - 1 ? 0 : Np.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(applicationStatusLabel(steps[i].status),
                            style: NpType.body.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w600,
                            )),
                        if (steps[i].at != null)
                          Text(dmy(steps[i].at),
                              style: NpType.meta
                                  .copyWith(fontSize: 12, color: c.muted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return AlertDialog(
      backgroundColor: c.surfaceHi,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rLg)),
      title: Text('Rút đơn?', style: NpType.h1.copyWith(color: c.ink)),
      content: Text(
        'Đơn ứng tuyển "$title" sẽ bị rút. Bạn vẫn nộp lại được chừng nào tin '
        'còn hạn.',
        style: NpType.meta.copyWith(color: c.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Huỷ', style: NpType.button.copyWith(color: c.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Rút đơn', style: NpType.button.copyWith(color: c.danger)),
        ),
      ],
    );
  }
}


/// Mời đẩy đơn — chỉ hiện với đơn còn mở, vì đẩy một đơn đã bị từ chối lên
/// đầu danh sách không giúp được gì.
class _BoostCard extends StatelessWidget {
  const _BoostCard({
    required this.boosted,
    required this.busy,
    required this.onBoost,
  });

  final bool boosted;
  final bool busy;
  final VoidCallback onBoost;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final price = WalletStore.instance.prices['boostPriceNp'];

    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, hi: true),
      child: Row(
        children: [
          NpIco(NpIcon.bolt, size: 20, color: boosted ? c.acidText : c.ink),
          const SizedBox(width: Np.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(boosted ? 'Đơn đang được đẩy' : 'Đẩy đơn lên đầu',
                    style: NpType.body.copyWith(
                        color: c.ink, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  boosted
                      ? 'Nhà tuyển dụng sẽ thấy đơn của bạn trước.'
                      : 'Nhà tuyển dụng thấy đơn của bạn trước các đơn khác.',
                  style: NpType.meta.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          if (!boosted) ...[
            const SizedBox(width: Np.s3),
            GestureDetector(
              onTap: busy ? null : onBoost,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s4, vertical: Np.s2 + 2),
                decoration: BoxDecoration(
                  color: c.acid,
                  borderRadius: BorderRadius.circular(Np.rPill),
                ),
                child: Text(
                  busy ? '…' : (price == null ? 'Đẩy' : '$price NP'),
                  style: NpType.button.copyWith(fontSize: 14, color: c.onAcid),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
