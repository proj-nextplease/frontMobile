import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../core/np_icons.dart';
import '../../core/widgets.dart';
import 'premium_page.dart';
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
      content: Text('Đã cộng NP (bản demo, không thu tiền thật).',
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
      body: RefreshIndicator(
        color: c.acidText,
        backgroundColor: c.surface,
        onRefresh: _store.hydrate,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Np.gutter, Np.s2, Np.gutter, Np.navInset),
          children: [
            _BalanceCard(store: _store, onTopUp: _topUp),
            const SizedBox(height: Np.s5),
            _PremiumRow(store: _store),
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
                  const SizedBox(width: Np.s2),
                  // Nói ngay trên nút, không đợi mở màn nạp mới biết.
                  Text('· demo',
                      style: NpType.meta.copyWith(
                          fontSize: 12,
                          color: c.onBand.withValues(alpha: 0.65))),
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

class _PremiumRow extends StatelessWidget {
  const _PremiumRow({required this.store});
  final WalletStore store;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final on = store.isPremium;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PremiumPage())),
      child: Container(
        padding: const EdgeInsets.all(Np.s4),
        decoration: Np.card(c),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: on ? c.acid : c.surfaceHi,
                borderRadius: BorderRadius.circular(Np.rSm),
              ),
              child: Center(
                child: NpIco(NpIcon.crown,
                    size: 20, color: on ? c.onAcid : c.muted),
              ),
            ),
            const SizedBox(width: Np.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(on ? 'Premium đang bật' : 'Premium',
                      style: NpType.title.copyWith(color: c.ink)),
                  const SizedBox(height: 2),
                  Text(
                    on
                        ? _until(store.premiumUntil)
                        : 'Boost đơn, mở Insight, nhận gợi ý sớm',
                    style: NpType.meta.copyWith(color: c.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            NpIco(NpIcon.arrow, size: 18, color: c.faint),
          ],
        ),
      ),
    );
  }

  static String _until(DateTime? d) =>
      d == null ? 'Đang hoạt động' : 'Đến ${fmtDate(d)}';
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
                      : '${fmtDate(tx.createdAt!)} · còn ${tx.balanceAfter} NP',
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
