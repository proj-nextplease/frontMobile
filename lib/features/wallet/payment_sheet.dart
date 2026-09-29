import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api_client.dart';
import '../../core/design.dart';
import 'wallet_store.dart';

/// Tên ngân hàng theo mã BIN. PayOS chỉ trả con số — hiện "970422" cho người
/// dùng thì vô nghĩa. Luôn có đường lùi về chính con số để không bao giờ hiện
/// ô trống.
const _bankNames = <String, String>{
  '970422': 'MB Bank',
  '970415': 'VietinBank',
  '970436': 'Vietcombank',
  '970418': 'BIDV',
  '970405': 'Agribank',
  '970407': 'Techcombank',
  '970416': 'ACB',
  '970432': 'VPBank',
  '970423': 'TPBank',
  '970403': 'Sacombank',
  '970441': 'VIB',
  '970437': 'HDBank',
  '970443': 'SHB',
  '970448': 'OCB',
  '970426': 'MSB',
};

/// PayOS đặt hạn 15 phút cho mỗi đơn; backend ghi expires_at cùng mốc.
const _expiry = Duration(minutes: 15);

/// Màn chuyển khoản, hiện sau khi đã tạo đơn.
///
/// ── Vì sao bố cục khác hẳn bản web ──
/// Trên web, mã QR là thứ chính: người dùng ngồi trước màn hình lớn và cầm
/// điện thoại quét. Trên điện thoại thì màn hình này và app ngân hàng nằm trên
/// CÙNG một máy — không camera nào quét được màn hình của chính nó. Nên ở đây
/// số tài khoản và nút sao chép mới là thứ chính; QR tụt xuống dưới, dành cho
/// người quét từ máy khác.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.request});

  final TopUpRequest request;

  /// Trả về số NP đã nạp nếu thành công, null nếu huỷ/hết hạn.
  static Future<int?> show(BuildContext context, TopUpRequest request) =>
      showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => PaymentSheet(request: request),
      );

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> with WidgetsBindingObserver {
  final _store = WalletStore.instance;

  Timer? _poll;
  Timer? _tick;

  /// Mốc hết hạn tính theo đồng hồ thật, không trừ dần theo nhịp timer.
  /// Trên điện thoại chuyện này là chắc chắn xảy ra chứ không phải thỉnh
  /// thoảng: người dùng rời app sang ngân hàng, hệ điều hành treo timer, quay
  /// lại thì đồng hồ đếm bằng biến sẽ sai hẳn vài phút.
  late final DateTime _deadline;

  Duration _left = _expiry;
  bool _closing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(_expiry);
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  /// Hỏi lại ngay khi người dùng quay về app.
  ///
  /// Đây là điểm khác biệt lớn nhất so với web. Người dùng BẮT BUỘC phải rời
  /// app để mở app ngân hàng, và trong lúc đó hệ điều hành treo mọi timer —
  /// vòng hỏi chết lặng. Không có chỗ này thì họ quay lại và thấy màn hình
  /// đứng nguyên ở "đang chờ" dù tiền đã vào từ lâu.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateClock();
      _check();
    }
  }

  void _updateClock() {
    if (!mounted) return;
    final left = _deadline.difference(DateTime.now());
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (left.isNegative) _finish(null);
  }

  Future<void> _check() async {
    if (_closing) return;
    try {
      final status = await _store.topUpStatus(widget.request.orderCode);
      if (!mounted || _closing) return;
      setState(() => _error = null);
      if (status == 'PAID') {
        await _store.refreshAfterTopUp();
        _finish(widget.request.amountVnd);
      } else if (status == 'CANCELLED' || status == 'FAILED' || status == 'EXPIRED') {
        _finish(null);
      }
    } on ApiException catch (e) {
      if (!mounted || _closing) return;
      /* Mạng chập chờn không phải lý do bỏ cuộc — tiền có thể đã chuyển rồi.
         Báo nhẹ rồi vẫn hỏi tiếp ở nhịp sau. */
      setState(() => _error = e.message);
    }
  }

  void _finish(int? paidAmount) {
    if (_closing || !mounted) return;
    _closing = true;
    _poll?.cancel();
    _tick?.cancel();
    Navigator.of(context).pop(paidAmount);
  }

  Future<void> _cancel() async {
    if (_closing) return;
    _closing = true;
    _poll?.cancel();
    _tick?.cancel();
    final orderCode = widget.request.orderCode;
    if (mounted) Navigator.of(context).pop(null);
    // Không chờ kết quả: huỷ được hay không cũng không đổi việc họ muốn thoát.
    _store.cancelTopUp(orderCode).catchError((_) {});
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép $label'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final r = widget.request;
    final bank = _bankNames[r.bin] ?? (r.bin.isEmpty ? 'Ngân hàng' : 'Ngân hàng ${r.bin}');
    final mm = _left.inMinutes.toString().padLeft(2, '0');
    final ss = (_left.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Np.rLg)),
      ),
      padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s4, Np.gutter, Np.s6),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chuyển khoản', style: NpType.h1.copyWith(color: c.ink)),
                        const SizedBox(height: Np.s1),
                        Text('${WalletStore.money(r.amountVnd)} VND',
                            style: NpType.h1.copyWith(color: c.acidText)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Np.s3, vertical: Np.s1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Np.rPill),
                      border: Border.all(
                          color: _left == Duration.zero ? c.danger : c.line),
                    ),
                    child: Text(
                      _left == Duration.zero ? 'Hết hạn' : '$mm:$ss',
                      style: NpType.meta.copyWith(
                        color: _left == Duration.zero ? c.danger : c.muted,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Np.s5),
              _Field(label: 'NGÂN HÀNG', value: bank, onCopy: () => _copy('tên ngân hàng', bank)),
              _Field(
                label: 'SỐ TÀI KHOẢN',
                value: r.accountNumber,
                mono: true,
                onCopy: () => _copy('số tài khoản', r.accountNumber),
              ),
              _Field(label: 'CHỦ TÀI KHOẢN', value: r.accountName),
              _Field(
                label: 'NỘI DUNG CHUYỂN KHOẢN',
                value: r.description,
                mono: true,
                onCopy: () => _copy('nội dung', r.description),
              ),

              const SizedBox(height: Np.s2),
              Text(
                'Giữ nguyên nội dung chuyển khoản — đó là thứ giúp hệ thống '
                'nhận ra khoản tiền này là của bạn.',
                style: NpType.meta.copyWith(color: c.muted, height: 1.5),
              ),

              const SizedBox(height: Np.s5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Np.s4),
                decoration: BoxDecoration(
                  color: c.acid.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Np.rMd),
                  border: Border.all(color: c.acid.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.acidText),
                    ),
                    const SizedBox(width: Np.s3),
                    Expanded(
                      child: Text(
                        'Đang chờ chuyển khoản. NP vào ví ngay khi nhận được '
                        'tiền — không cần bấm gì thêm.',
                        style: NpType.meta.copyWith(color: c.ink, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: Np.s3),
                Text(_error!, style: NpType.meta.copyWith(color: c.danger)),
              ],

              if (r.qrCode.isNotEmpty) ...[
                const SizedBox(height: Np.s5),
                Center(
                  child: Column(
                    children: [
                      /* Nền trắng cứng, không theo màu nền app. Mã QR phải là
                         đen trên trắng; tô theo tông neon cho hợp mắt là cách
                         nhanh nhất làm camera không đọc được. */
                      Container(
                        padding: const EdgeInsets.all(Np.s3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Np.rMd),
                        ),
                        child: QrImageView(
                          data: r.qrCode,
                          size: 150,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: Np.s2),
                      Text('Hoặc quét mã này bằng máy khác',
                          style: NpType.meta.copyWith(color: c.muted)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: Np.s5),
              GestureDetector(
                onTap: _cancel,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: Np.s4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Np.rPill),
                    border: Border.all(color: c.line),
                  ),
                  child: Text('Huỷ thanh toán',
                      style: NpType.body.copyWith(
                          color: c.muted, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một dòng thông tin chuyển khoản kèm nút sao chép.
///
/// Nút sao chép để to và tách hẳn ra: trên điện thoại đây là thao tác chính
/// của cả màn hình, không phải tiện ích phụ như trên web.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.onCopy,
    this.mono = false,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Np.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: NpType.label.copyWith(color: c.muted)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: NpType.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w700,
                    fontFeatures:
                        mono ? const [FontFeature.tabularFigures()] : null,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            GestureDetector(
              onTap: onCopy,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s3, vertical: Np.s2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 14, color: c.acidText),
                    const SizedBox(width: Np.s1),
                    Text('Sao chép',
                        style: NpType.meta.copyWith(
                            color: c.acidText, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
