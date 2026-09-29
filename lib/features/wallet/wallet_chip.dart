import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../core/np_icons.dart';
import 'topup_sheet.dart';

/// Nút ví NP ở góc trên mỗi tab — lối nạp tiền từ bất cứ đâu.
///
/// Trước đây muốn nạp NP phải đi Hồ sơ → Ví NP → Nạp: ba bước, và chỉ nghĩ ra
/// được nếu đã biết ví nằm ở đó. Nhưng lúc người dùng THẬT SỰ cần nạp thường
/// là lúc họ đang đứng chỗ khác — vừa thấy một tin Premium ở tab Cơ hội, hoặc
/// vừa định đẩy một đơn lên đầu.
///
/// Chỉ là biểu tượng, KHÔNG kèm số dư. Bản đầu tôi có hiện số, nhưng header
/// trang chủ vốn đã chật (avatar, nhãn Premium, lời chào, điểm uy tín, chuông)
/// và thêm một con số nữa là tràn mất 66px. Số dư đã hiện ở tab Hồ sơ và màn
/// Ví; chỗ này chỉ cần là một lối đi.
///
/// Kích thước và cách dựng bám theo [NotificationBell] để hai nút đứng cạnh
/// nhau trông như một cặp, không phải hai thứ chắp vá.
class WalletChip extends StatelessWidget {
  const WalletChip({super.key, this.size = 22, this.color});

  final double size;

  /// Màu biểu tượng. Null thì dùng màu chữ chính của nền hiện tại.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return GestureDetector(
      onTap: () => TopUpSheet.show(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size + 19,
        height: size + 19,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            NpIco(NpIcon.wallet, size: size, color: color ?? c.ink),
            /* Dấu cộng nhỏ ở góc: phân biệt "mở ví để xem" với "nạp thêm".
               Không có nó thì biểu tượng ví đọc ra là một lối xem số dư. */
            Positioned(
              right: 1,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.bg),
                child: NpIco(NpIcon.plus, size: 9, color: c.acidText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
