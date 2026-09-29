import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/design.dart';
import '../../core/widgets.dart';
import 'payment_sheet.dart';
import 'topup_success_sheet.dart';
import 'wallet_store.dart';

/// Màn chọn số tiền nạp NP.
///
/// Tiền thật, qua PayOS. Bấm nút là tạo đơn rồi mở [PaymentSheet] để chuyển
/// khoản; NP chỉ vào ví khi PayOS báo về backend đã nhận được tiền.
///
/// Trước đây đây là luồng giả lập cộng thẳng NP vào ví, và cả màn hình có một
/// nhãn cảnh báo to đặt ngay trên nút. Nhãn đó đã bỏ cùng lúc với luồng giả
/// lập — để lại thì thành nói dối theo chiều ngược lại.
class TopUpSheet extends StatefulWidget {
  const TopUpSheet({super.key});

  /// Mở dạng tấm trượt từ đáy. Trả true nếu nạp thành công.
  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const TopUpSheet(),
      );

  @override
  State<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<TopUpSheet> {
  final _store = WalletStore.instance;
  final _ctrl = TextEditingController(text: '50000');

  bool _busy = false;
  String? _error;

  /// Các mức nhanh, đủ để demo mà không phải gõ.
  static const _quick = [50000, 100000, 200000, 500000];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_ctrl.text.replaceAll('.', '').trim()) ?? 0;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final TopUpRequest request;
    try {
      request = await _store.createTopUp(_amount);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);

    // Màn chuyển khoản trả về số NP đã nạp, hoặc null nếu huỷ/hết hạn.
    final paid = await PaymentSheet.show(context, request);
    if (!mounted) return;

    if (paid == null) {
      // Huỷ hoặc hết hạn: ở lại màn chọn số tiền để nạp lại ngay được.
      // Đóng hẳn ở đây thì người dùng phải mở lại từ đầu chỉ vì đổi ý một lần.
      setState(() => _error = null);
      return;
    }

    await TopUpSuccessSheet.show(context, amountNp: paid, balance: _store.balance);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
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
              Text('1 VND = 1 NP · Số dư hiện tại ${WalletStore.money(_store.balance)} NP',
                  style: NpType.meta.copyWith(color: c.muted)),

              const SizedBox(height: Np.s5),
              Text('SỐ TIỀN (VND)',
                  style: NpType.label.copyWith(color: c.muted)),
              const SizedBox(height: Np.s2),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() => _error = null),
                style: NpType.h1.copyWith(color: c.ink),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '50000',
                  hintStyle: NpType.h1.copyWith(color: c.faint),
                  enabledBorder:
                      UnderlineInputBorder(borderSide: BorderSide(color: c.line)),
                  focusedBorder:
                      UnderlineInputBorder(borderSide: BorderSide(color: c.acid)),
                ),
              ),

              const SizedBox(height: Np.s3),
              Wrap(
                spacing: Np.s2,
                runSpacing: Np.s2,
                children: [
                  for (final v in _quick)
                    GestureDetector(
                      onTap: () => setState(() {
                        _ctrl.text = '$v';
                        _error = null;
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Np.s4, vertical: Np.s2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Np.rPill),
                          border: Border.all(
                              color: _amount == v ? c.acid : c.line),
                          color: _amount == v
                              ? c.acid.withValues(alpha: 0.12)
                              : Colors.transparent,
                        ),
                        child: Text(WalletStore.money(v),
                            style: NpType.meta.copyWith(
                                fontWeight: FontWeight.w600, color: c.ink)),
                      ),
                    ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: Np.s4),
                Text(_error!, style: NpType.meta.copyWith(color: c.danger)),
              ],

              const SizedBox(height: Np.s4),
              AcidButton(
                label: _busy
                    ? 'Đang tạo đơn…'
                    : 'Nạp ${WalletStore.money(_amount)} NP',
                busy: _busy,
                enabled: !_busy && _amount >= _store.minTopupVnd,
                onTap: _submit,
              ),

              if (_amount > 0 && _amount < _store.minTopupVnd) ...[
                const SizedBox(height: Np.s2),
                Text(
                  'Tối thiểu ${WalletStore.money(_store.minTopupVnd)} VND.',
                  style: NpType.meta.copyWith(color: c.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
