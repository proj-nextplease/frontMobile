import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design.dart';
import 'wallet_store.dart';

/// Bao nhiêu giây thì tự đóng. Đủ lâu để đọc số dư mới, đủ ngắn để không phải
/// ngồi chờ.
const _autoClose = 6;

/// Màn báo nạp thành công, tự đóng sau vài giây.
///
/// Nút đóng vẫn bấm được suốt: đếm ngược là tiện ích, không phải thứ bắt người
/// dùng phải chờ hết giờ.
class TopUpSuccessSheet extends StatefulWidget {
  const TopUpSuccessSheet({super.key, required this.amountNp, required this.balance});

  final int amountNp;
  final int balance;

  static Future<void> show(BuildContext context,
          {required int amountNp, required int balance}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TopUpSuccessSheet(amountNp: amountNp, balance: balance),
      );

  @override
  State<TopUpSuccessSheet> createState() => _TopUpSuccessSheetState();
}

class _TopUpSuccessSheetState extends State<TopUpSuccessSheet> {
  /// Đếm theo đồng hồ thật, cùng lý do như mọi đồng hồ khác trong luồng này.
  late final DateTime _deadline;
  Timer? _timer;
  int _left = _autoClose;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(const Duration(seconds: _autoClose));
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final ms = _deadline.difference(DateTime.now()).inMilliseconds;
      final left = ms <= 0 ? 0 : (ms / 1000).ceil();
      if (left != _left) setState(() => _left = left);
      if (left == 0) _close();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    _timer?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final pct = (_left / _autoClose).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Np.rLg)),
      ),
      padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s6, Np.gutter, Np.s6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.acid,
                  boxShadow: [
                    BoxShadow(
                      color: c.acid.withValues(alpha: 0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.check_rounded, size: 34, color: c.onAcid),
              ),
            ),
            const SizedBox(height: Np.s4),

            Text('Nạp thành công', style: NpType.h1.copyWith(color: c.ink)),
            const SizedBox(height: Np.s2),
            Text('+${WalletStore.money(widget.amountNp)} NP',
                style: NpType.h1.copyWith(color: c.acidText, fontSize: 30)),
            const SizedBox(height: Np.s2),
            Text('Số dư hiện tại ${WalletStore.money(widget.balance)} NP',
                style: NpType.meta.copyWith(color: c.muted)),

            /* Thanh vơi dần cho biết tấm này sắp tự đóng. Thiếu nó thì nó tự
               biến mất trông như lỗi. */
            const SizedBox(height: Np.s5),
            ClipRRect(
              borderRadius: BorderRadius.circular(Np.rPill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: pct, end: pct),
                duration: const Duration(milliseconds: 220),
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 3,
                  backgroundColor: c.line,
                  valueColor: AlwaysStoppedAnimation(c.acid),
                ),
              ),
            ),

            const SizedBox(height: Np.s4),
            GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: Np.s4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.acid,
                  borderRadius: BorderRadius.circular(Np.rPill),
                ),
                child: Text(
                  _left > 0 ? 'Đóng (${_left}s)' : 'Đóng',
                  style: NpType.body.copyWith(
                      color: c.onAcid, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
