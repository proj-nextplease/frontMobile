import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../core/np_icons.dart';
import '../../core/widgets.dart';
import 'topup_sheet.dart';
import 'wallet_store.dart';

/// Ví NP: số dư, các gói đang bật, và lịch sử giao dịch.
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _store = WalletStore.instance;

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

  Future<void> _topUp() async {
    final ok = await TopUpSheet.show(context);
    if (ok != true || !mounted) return;
    // Kho đã tự nạp lại sau khi nạp tiền; chỉ cần báo cho người dùng.
    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: c.surfaceHi,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
      content: Text('Đã cộng NP vào ví.',
          style: NpType.body.copyWith(fontSize: 14, color: c.ink)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final txs = _store.transactions;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Ví NP', style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NeonMeshBackground(height: 480, opacity: 0.65),
          ),
          RefreshIndicator(
            color: c.acidText,
            backgroundColor: c.surface,
            onRefresh: _store.hydrate,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Np.gutter, Np.s2, Np.gutter, Np.navInset),
              children: [
                _BalanceCard(store: _store, onTopUp: _topUp),
                const SizedBox(height: Np.s5),
                const SectionLabel('Biểu phí'),
                const SizedBox(height: Np.s3),
                _FeeCard(store: _store),
                const SizedBox(height: Np.s6),
                const SectionLabel('Lịch sử giao dịch'),
                const SizedBox(height: Np.s3),
                if (!_store.loaded)
                  _Placeholder(text: 'Đang tải…', c: c)
                else if (txs.isEmpty)
                  _Placeholder(
                    text: 'Chưa có giao dịch nào.\n'
                        'NP kiếm được từ nhiệm vụ sẽ hiện ở đây.',
                    c: c,
                  )
                else
                  for (final t in txs) _TxRow(tx: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.store, required this.onTopUp});
  final WalletStore store;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Np.s5),
      decoration: BoxDecoration(
        color: c.band,
        borderRadius: BorderRadius.circular(Np.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NpIco(NpIcon.wallet, size: 18, color: c.onBand.withValues(alpha: 0.7)),
              const SizedBox(width: Np.s2),
              Text('SỐ DƯ',
                  style: NpType.label
                      .copyWith(color: c.onBand.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: Np.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${store.balance}',
                  style: NpType.display.copyWith(color: c.onBand)),
              const SizedBox(width: Np.s2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('NP',
                    style: NpType.title
                        .copyWith(color: c.onBand.withValues(alpha: 0.75))),
              ),
            ],
          ),
          const SizedBox(height: Np.s4),
          GestureDetector(
            onTap: onTopUp,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Np.s4, vertical: Np.s2 + 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Np.rPill),
                border: Border.all(color: c.onBand.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NpIco(NpIcon.plus, size: 15, color: c.onBand),
                  const SizedBox(width: Np.s2),
                  Text('Nạp NP',
                      style: NpType.button
                          .copyWith(fontSize: 14, color: c.onBand)),
                ],
              ),
            ),
          ),

          // Chỉ hiện khi thực sự có NP bị giữ. Luôn hiện "0 đang tạm giữ" là
          // thêm một dòng vô nghĩa vào thứ quan trọng nhất màn hình.
          if (store.locked > 0) ...[
            const SizedBox(height: Np.s2),
            Text('${store.locked} NP đang tạm giữ cho giao dịch chưa xong',
                style: NpType.meta
                    .copyWith(color: c.onBand.withValues(alpha: 0.75))),
          ],
        ],
      ),
    );
  }
}

/// Biểu phí — cùng nội dung với tab Cửa hàng trên web: chỉ HAI thứ tính
/// điểm, còn lại miễn phí. Gói Premium, đẩy đơn, Insight, duyệt nhanh đã bỏ.
class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.store});
  final WalletStore store;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    Widget row(String title, String note, String price, {bool free = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Np.s2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: NpType.body.copyWith(
                            color: c.ink, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(note,
                        style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: Np.s3),
              Text(price,
                  style: NpType.meta.copyWith(
                    fontWeight: FontWeight.w700,
                    color: free ? c.muted : c.acidText,
                  )),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(Np.s4, Np.s2, Np.s4, Np.s2),
      decoration: Np.card(c),
      child: Column(
        children: [
          row('Nhận việc có thù lao',
              'Chỉ trừ khi bạn đồng ý lời mời nhận việc',
              '${WalletStore.money(store.jobAcceptanceFeeNp)} NP'),
          Divider(color: c.line, height: 1),
          row('Cập nhật website portfolio',
              'Lần xuất bản đầu tiên miễn phí',
              '${WalletStore.money(store.portfolioExportFeeNp)} NP'),
          Divider(color: c.line, height: 1),
          row('Ứng tuyển, sửa hồ sơ, nộp minh chứng',
              'Không giới hạn', 'Miễn phí',
              free: true),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});
  final WalletTx tx;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final gain = tx.amount >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: Np.s2),
      padding: const EdgeInsets.symmetric(
          horizontal: Np.s4, vertical: Np.s3),
      decoration: Np.card(c, radius: Np.rMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.reason ?? txLabel(tx.type),
                    style: NpType.body
                        .copyWith(color: c.ink, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  tx.createdAt == null
                      ? 'Số dư sau: ${tx.balanceAfter} NP'
                      : '${fmtDateTime(tx.createdAt!)} · còn ${tx.balanceAfter} NP',
                  style: NpType.meta.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Np.s3),
          Text(
            '${gain ? '+' : '−'}${tx.amount.abs()}',
            // Chi tiêu dùng màu mực bình thường chứ không phải màu cảnh báo:
            // tiêu NP là việc người dùng CHỦ ĐỘNG làm, không phải lỗi.
            style: NpType.title.copyWith(color: gain ? c.acidText : c.ink),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text, required this.c});
  final String text;
  final NpColors c;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: Np.s8),
        decoration: Np.card(c),
        child: Text(text,
            textAlign: TextAlign.center,
            style: NpType.meta.copyWith(color: c.muted)),
      );
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Ngày KÈM giờ, dùng cho lịch sử giao dịch.
///
/// Tách khỏi [fmtDate] chứ không sửa thẳng hàm đó: fmtDate còn dùng cho hạn
/// Premium và hạn Job Match Alert, mà "Đến 29/10/2026 14:05" thì con số giờ ở
/// đó vô nghĩa.
///
/// Giờ quan trọng ở lịch sử vì trong cùng một ngày có thể có nhiều giao dịch —
/// nạp tiền, mua gói, rồi hoàn tiền — và không có giờ thì không xếp được thứ
/// tự, cũng không đối chiếu được với biên lai ngân hàng.
String fmtDateTime(DateTime d) =>
    '${fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Nhãn tiếng Việt cho mã giao dịch. Chỉ dùng khi backend không kèm `reason`.
String txLabel(String type) => switch (type) {
      'EARN' || 'REWARD' => 'Nhận thưởng',
      'SPEND' || 'PURCHASE' => 'Chi tiêu',
      'TOPUP' => 'Nạp NP',
      'REFUND' => 'Hoàn NP',
      'BOOST' => 'Đẩy đơn ứng tuyển',
      'SUBSCRIPTION' => 'Gói trả phí',
      _ => 'Giao dịch',
    };
