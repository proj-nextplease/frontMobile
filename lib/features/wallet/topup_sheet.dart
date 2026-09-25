import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design.dart';
import '../../core/widgets.dart';
import 'wallet_store.dart';

/// Màn nạp NP.
///
/// ⚠️ ĐÂY LÀ LUỒNG GIẢ LẬP. Backend ghi payment_requests với provider 'MOCK',
/// status 'PAID' ngay lập tức rồi cộng thẳng vào ví — không có cổng thanh
/// toán, không thu một đồng nào.
///
/// Vì vậy dòng cảnh báo đặt NGAY TRÊN nút bấm, không phải cuối trang. Một
/// luồng nạp tiền trông như thật mà không thu tiền là thứ nguy hiểm nhất có
/// thể dựng trong một app; nếu đã dựng thì nhãn phải nằm ở chỗ người dùng
/// buộc phải đọc trước khi bấm, chứ không phải chỗ họ cuộn qua.
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

    final err = await _store.topUp(_amount);

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
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

              // ── Nhãn cảnh báo, ngay trên nút ─────────────────────────
              const SizedBox(height: Np.s5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Np.s4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Np.rMd),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Bản demo — KHÔNG thu tiền thật.\n'
                  'Chưa có cổng thanh toán nào được nối. Bấm nút bên dưới là '
                  'NP được cộng thẳng vào ví, không có giao dịch nào diễn ra.',
                  style: NpType.meta
                      .copyWith(color: const Color(0xFF78350F), height: 1.5),
                ),
              ),

              const SizedBox(height: Np.s4),
              AcidButton(
                label: _busy
                    ? 'Đang xử lý…'
                    : 'Cộng ${WalletStore.money(_amount)} NP (demo)',
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
