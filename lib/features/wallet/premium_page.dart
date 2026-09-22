import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../core/np_icons.dart';
import '../../core/widgets.dart';
import 'wallet_page.dart' show fmtDate;
import 'wallet_store.dart';

/// Bảng giá các dịch vụ trả bằng NP.
///
/// Chỉ hiện những thứ MUA ĐƯỢC ngay tại đây (Premium, Job Match Alert). Boost
/// và Insight cần một đơn/tin cụ thể nên chỉ liệt kê giá — nút bấm của chúng
/// nằm trong màn chi tiết đơn, nơi câu "đẩy đơn NÀY" mới có nghĩa.
class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final _store = WalletStore.instance;
  String? _busy;

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

  Future<void> _buy(String key, int price, String name,
      Future<String?> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmSheet(name: name, price: price),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = key);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = null);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Đã kích hoạt $name'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final p = _store.prices;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Premium', style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Np.gutter, Np.s2, Np.gutter, Np.navInset),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Np.s4, vertical: Np.s3),
            decoration: Np.card(c, hi: true),
            child: Row(
              children: [
                NpIco(NpIcon.wallet, size: 18, color: c.muted),
                const SizedBox(width: Np.s2),
                Text('Bạn đang có ',
                    style: NpType.body.copyWith(color: c.muted)),
                Text('${_store.balance} NP',
                    style: NpType.body.copyWith(
                        color: c.ink, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: Np.s5),

          _Card(
            icon: NpIcon.crown,
            title: 'Premium Pass',
            body: 'Mở toàn bộ tính năng trả phí trong thời hạn gói: '
                'đẩy đơn, xem Insight, và thấy tin mới sớm hơn '
                '${_hours(p['earlyAccessHours'])}.',
            price: _store.premiumPriceNp,
            active: _store.isPremium,
            activeNote: _until(_store.premiumUntil),
            busy: _busy == 'premium',
            balance: _store.balance,
            onBuy: () => _buy('premium', _store.premiumPriceNp,
                'Premium Pass', _store.buyPremium),
          ),
          const SizedBox(height: Np.s3),

          _Card(
            icon: NpIcon.bell,
            title: 'Job Match Alert',
            body: 'Nhận thông báo ngay khi có tin tuyển dụng khớp với kỹ năng '
                'và điểm RS của bạn, thay vì phải tự vào xem.',
            price: p['matchAlertPriceNp'] ?? 0,
            active: _store.hasMatchAlert,
            activeNote: _until(_store.matchAlertUntil),
            busy: _busy == 'alert',
            balance: _store.balance,
            onBuy: () => _buy('alert', p['matchAlertPriceNp'] ?? 0,
                'Job Match Alert', _store.subscribeMatchAlert),
          ),

          const SizedBox(height: Np.s6),
          const SectionLabel('Mua theo từng lần'),
          const SizedBox(height: Np.s3),
          _PriceLine(
            label: 'Đẩy một đơn ứng tuyển lên đầu',
            note: 'trong ${_hours(p['boostDurationHours'])}',
            price: p['boostPriceNp'],
            where: 'Mở trong màn chi tiết đơn đã nộp',
          ),
          _PriceLine(
            label: 'Mở Insight một tin',
            note: 'xem số người đã nộp và mức độ cạnh tranh',
            price: p['insightPriceNp'],
            where: 'Mở trong màn chi tiết tin',
          ),
          _PriceLine(
            label: 'Xác thực minh chứng nhanh',
            note: 'được duyệt trước hàng chờ',
            price: p['expressPriceNp'],
            where: 'Mở trong màn minh chứng',
          ),
        ],
      ),
    );
  }

  static String _hours(int? h) => h == null ? 'một thời gian' : '$h giờ';
  static String _until(DateTime? d) =>
      d == null ? 'Đang hoạt động' : 'Đến ${fmtDate(d)}';
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.body,
    required this.price,
    required this.active,
    required this.activeNote,
    required this.busy,
    required this.balance,
    required this.onBuy,
  });

  final NpIcon icon;
  final String title;
  final String body;
  final int price;
  final bool active;
  final String activeNote;
  final bool busy;
  final int balance;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final affordable = balance >= price && price > 0;

    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: Np.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NpIco(icon, size: 20, color: active ? c.acidText : c.ink),
              const SizedBox(width: Np.s2),
              Expanded(
                child: Text(title,
                    style: NpType.title.copyWith(color: c.ink)),
              ),
              if (active) MetaChip(label: 'Đang bật', accent: true),
            ],
          ),
          const SizedBox(height: Np.s2),
          Text(body, style: NpType.body.copyWith(color: c.muted)),
          const SizedBox(height: Np.s4),
          if (active)
            Text(activeNote,
                style: NpType.meta.copyWith(
                    color: c.acidText, fontWeight: FontWeight.w600))
          else ...[
            AcidButton(
              label: busy ? 'Đang xử lý…' : 'Kích hoạt · $price NP',
              busy: busy,
              enabled: affordable && !busy,
              onTap: onBuy,
            ),
            // Nói rõ vì sao nút xám, thay vì để người dùng bấm vào một nút
            // chết và tự đoán.
            if (!affordable && price > 0) ...[
              const SizedBox(height: Np.s2),
              Text(
                'Bạn còn thiếu ${price - balance} NP. '
                'Hoàn thành nhiệm vụ hằng ngày để kiếm thêm.',
                style: NpType.meta.copyWith(color: c.muted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.note,
    required this.price,
    required this.where,
  });

  final String label;
  final String note;
  final int? price;
  final String where;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Np.s2),
      padding: const EdgeInsets.symmetric(
          horizontal: Np.s4, vertical: Np.s3),
      decoration: Np.card(c, radius: Np.rMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: NpType.body.copyWith(
                        color: c.ink, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('$note · $where',
                    style: NpType.meta.copyWith(color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: Np.s3),
          Text(price == null ? '—' : '$price NP',
              style: NpType.body.copyWith(
                  color: c.ink, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Hỏi lại trước khi trừ NP. Trừ tiền không hỏi là cách nhanh nhất làm người
/// dùng mất lòng tin vào ví.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.name, required this.price});
  final String name;
  final int price;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Np.rLg)),
      title: Text('Xác nhận', style: NpType.title.copyWith(color: c.ink)),
      content: Text('Kích hoạt $name sẽ trừ $price NP khỏi ví của bạn.',
          style: NpType.body.copyWith(color: c.muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Huỷ', style: NpType.button.copyWith(color: c.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Đồng ý',
              style: NpType.button.copyWith(color: c.acidText)),
        ),
      ],
    );
  }
}
