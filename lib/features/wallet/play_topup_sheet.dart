import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/design.dart';
import '../../core/widgets.dart';
import 'play_billing.dart';
import 'topup_success_sheet.dart';
import 'wallet_store.dart';

/// Màn nạp NP trên Android — mua gói cố định qua Google Play.
///
/// Khác bản PayOS ở hai chỗ: không nhập số tiền tự do (Google Play chỉ bán
/// sản phẩm có giá định sẵn), và giá hiển thị lấy từ Google Play chứ không tự
/// ghi — Google quyết định cách hiện giá theo vùng của người mua.
class PlayTopUpSheet extends StatefulWidget {
  const PlayTopUpSheet({super.key});

  @override
  State<PlayTopUpSheet> createState() => _PlayTopUpSheetState();
}

class _PlayTopUpSheetState extends State<PlayTopUpSheet> {
  final _store = WalletStore.instance;
  final _billing = PlayBilling.instance;
  StreamSubscription<PlayPurchaseEvent>? _sub;

  List<ProductDetails>? _products;
  ProductDetails? _selected;
  bool _busy = false;
  String? _error;
  String? _info;

  /// Tên gói, giống tab Cửa hàng trên web.
  static const _tierNames = {
    39000: 'Khởi đầu',
    69000: 'Năng động',
    99000: 'Bứt phá',
    199000: 'Dài hạn',
  };

  @override
  void initState() {
    super.initState();
    _sub = _billing.events.listen(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _billing.loadProducts();
      if (!mounted) return;
      setState(() {
        _products = list;
        _selected = list.isEmpty ? null : list.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _products = const []);
    }
  }

  int _np(ProductDetails p) => PlayBilling.productNp[p.id] ?? 0;

  /// Gói này dùng được vào việc gì — cùng cách tính với web.
  String? _perk(int a) {
    final job = _store.jobAcceptanceFeeNp;
    final exp = _store.portfolioExportFeeNp;
    if (a <= 0 || job <= 0 || exp <= 0) return null;
    final jobs = a ~/ job;
    final exports = (a % job) ~/ exp;
    final parts = [
      if (jobs > 0) 'Đủ nhận $jobs việc có thù lao',
      if (exports > 0) '${jobs > 0 ? 'dư' : 'Đủ'} $exports lần cập nhật website',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  Future<void> _buy() async {
    final p = _selected;
    if (p == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final started = await _billing.buy(p);
      if (!started && mounted) {
        setState(() {
          _busy = false;
          _error = 'Không mở được thanh toán Google Play. Thử lại sau.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Không mở được thanh toán Google Play. Thử lại sau.';
      });
    }
  }

  Future<void> _onEvent(PlayPurchaseEvent e) async {
    if (!mounted) return;
    switch (e.kind) {
      case PlayPurchaseKind.pending:
        setState(() {
          _busy = false;
          _info = 'Giao dịch đang chờ Google Play xác nhận. '
              'NP sẽ vào ví ngay khi thanh toán hoàn tất.';
        });
      case PlayPurchaseKind.canceled:
        setState(() => _busy = false);
      case PlayPurchaseKind.failed:
        setState(() {
          _busy = false;
          _error = e.message;
        });
      case PlayPurchaseKind.success:
        setState(() => _busy = false);
        await TopUpSuccessSheet.show(context,
            amountNp: e.amountNp, balance: _store.balance);
        if (!mounted) return;
        Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final products = _products;
    final selectedNp = _selected == null ? 0 : _np(_selected!);
    final perk = _perk(selectedNp);

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Np.rLg)),
      ),
      padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s4, Np.gutter, Np.s6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(Np.rPill),
                ),
              ),
            ),
            const SizedBox(height: Np.s5),
            Text('Nạp NP', style: NpType.h1.copyWith(color: c.ink)),
            const SizedBox(height: Np.s1),
            Text('Thanh toán qua Google Play · Số dư hiện tại '
                '${WalletStore.money(_store.balance)} NP',
                style: NpType.meta.copyWith(color: c.muted)),
            const SizedBox(height: Np.s5),

            if (products == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Np.s6),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Np.s4),
                child: Text(
                  'Các gói NP đang được cập nhật. Vui lòng quay lại sau.',
                  style: NpType.body.copyWith(color: c.muted),
                ),
              )
            else ...[
              Text('CHỌN GÓI', style: NpType.label.copyWith(color: c.muted)),
              const SizedBox(height: Np.s2),
              for (final p in products) ...[
                _PackRow(
                  np: _np(p),
                  tier: _tierNames[_np(p)],
                  price: p.price,
                  selected: _selected?.id == p.id,
                  onTap: _busy
                      ? null
                      : () => setState(() {
                            _selected = p;
                            _error = null;
                          }),
                ),
                const SizedBox(height: Np.s2),
              ],
              if (perk != null) ...[
                const SizedBox(height: Np.s1),
                Text('→ $perk.',
                    style: NpType.meta.copyWith(
                        color: c.acidText, fontWeight: FontWeight.w600)),
              ],
            ],

            if (_info != null) ...[
              const SizedBox(height: Np.s4),
              Text(_info!, style: NpType.meta.copyWith(color: c.muted)),
            ],
            if (_error != null) ...[
              const SizedBox(height: Np.s4),
              Text(_error!, style: NpType.meta.copyWith(color: c.danger)),
            ],

            const SizedBox(height: Np.s4),
            AcidButton(
              label: _busy
                  ? 'Đang xử lý…'
                  : _selected == null
                      ? 'Nạp NP'
                      : 'Mua ${WalletStore.money(selectedNp)} NP · ${_selected!.price}',
              busy: _busy,
              enabled: !_busy && _selected != null,
              onTap: _buy,
            ),
          ],
        ),
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.np,
    required this.tier,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final int np;
  final String? tier;
  final String price;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Np.s4, vertical: Np.s3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Np.rMd),
          border: Border.all(color: selected ? c.acid : c.line),
          color: selected ? c.acid.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${WalletStore.money(np)} NP',
                      style: NpType.body.copyWith(
                          color: c.ink, fontWeight: FontWeight.w700)),
                  if (tier != null)
                    Text(tier!, style: NpType.meta.copyWith(color: c.muted)),
                ],
              ),
            ),
            Text(price,
                style: NpType.body.copyWith(
                    color: c.ink, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
