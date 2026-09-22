import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bộ biểu tượng riêng của nextplease.
///
/// Vì sao không dùng Icons.* của Material: đó là bộ Google phát sẵn, và nó là
/// dấu hiệu rõ nhất của một app "chưa ai buồn thiết kế". Mọi app Flutter dựng
/// nhanh đều dùng đúng bộ đó, nên người dùng nhận ra ngay dù không gọi tên
/// được.
///
/// Bộ này vẽ tay, thống nhất ba quy tắc:
///   - nét 1.7px, đầu và khớp BO TRÒN — mềm hơn Material, hợp giọng trẻ
///   - khung 24×24, phần vẽ nằm gọn trong 3..21 để các icon cân nhau
///   - hình học đơn giản, không chi tiết vụn: ở cỡ 22px mọi thứ nhỏ hơn 2px
///     đều bết lại thành vệt mờ
enum NpIcon { home, jobs, chat, person, search, heart, heartFill, bolt, bell, flame, send, arrow, company }

class NpIco extends StatelessWidget {
  const NpIco(this.icon, {super.key, this.size = 22, required this.color});

  final NpIcon icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    return SvgPicture.string(
      _svg(icon, hex),
      width: size,
      height: size,
    );
  }
}

String _svg(NpIcon i, String c) {
  const open = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke-width="1.7" stroke-linecap="round" '
      'stroke-linejoin="round">';
  return '$open${_body(i, c)}</svg>';
}

String _body(NpIcon i, String c) => switch (i) {
      // Mái nhà cộng một vòm cửa. Vòm chứ không phải ô vuông: đó là chi tiết
      // duy nhất tách nó khỏi mọi icon nhà khác.
      NpIcon.home => '<path stroke="$c" d="M3.6 10.4 12 3.6l8.4 6.8v8.3a1.7 1.7 0 0 1-1.7 1.7H5.3a1.7 1.7 0 0 1-1.7-1.7z"/>'
          '<path stroke="$c" d="M9.3 20.4v-4.2a2.7 2.7 0 0 1 5.4 0v4.2"/>',

      // Cặp tài liệu, quai hình thang chứ không phải chữ nhật — nhìn ra là
      // cặp học sinh hơn là vali công sở.
      NpIcon.jobs => '<rect stroke="$c" x="3.2" y="7.8" width="17.6" height="12.4" rx="2.6"/>'
          '<path stroke="$c" d="M8.6 7.8V6.2a2 2 0 0 1 2-2h2.8a2 2 0 0 1 2 2v1.6"/>'
          '<path stroke="$c" d="M3.2 12.9h17.6"/>',

      // Hai bong bóng chồng nhau, cái sau thò ra góc — gợi đối thoại chứ
      // không phải một lời nhắn đơn.
      NpIcon.chat => '<path stroke="$c" d="M3.4 8.2a2.6 2.6 0 0 1 2.6-2.6h7.6a2.6 2.6 0 0 1 2.6 2.6v3.6a2.6 2.6 0 0 1-2.6 2.6H8.1L4.6 17v-2.9a2.6 2.6 0 0 1-1.2-2.3z"/>'
          '<path stroke="$c" d="M17.6 9.6h1a2.6 2.6 0 0 1 2.6 2.6v3.6a2.6 2.6 0 0 1-1.2 2.2V21l-3.4-2.6h-3.9"/>',

      NpIcon.person => '<circle stroke="$c" cx="12" cy="8.4" r="3.6"/>'
          '<path stroke="$c" d="M4.8 20.4a7.2 7.2 0 0 1 14.4 0"/>',

      NpIcon.search => '<circle stroke="$c" cx="10.9" cy="10.9" r="6.7"/>'
          '<path stroke="$c" d="m15.9 15.9 4.5 4.5"/>',

      NpIcon.heart => '<path stroke="$c" d="M12 20.3S3.7 15 3.7 9.4a4.7 4.7 0 0 1 8.3-3 4.7 4.7 0 0 1 8.3 3c0 5.6-8.3 10.9-8.3 10.9z"/>',

      NpIcon.heartFill => '<path fill="$c" d="M12 20.3S3.7 15 3.7 9.4a4.7 4.7 0 0 1 8.3-3 4.7 4.7 0 0 1 8.3 3c0 5.6-8.3 10.9-8.3 10.9z"/>',

      // Tia sét cho EXP.
      NpIcon.bolt => '<path stroke="$c" d="M13.4 3.2 5.6 13.4h5.3l-.9 7.4 8-10.2h-5.4z"/>',

      // Toà nhà — dùng khi tổ chức không có logo.
      //
      // Vì sao không để chữ cái đầu: "CT" cho "CTY KT" không nói được gì, và
      // một danh sách toàn ô chữ hai ký tự trông như bảng mã. Một hình đồ hoạ
      // nói ngay "đây là một tổ chức", kể cả khi chưa đọc tên.
      //
      // Hai khối CAO THẤP khác nhau chứ không phải một hộp: hộp đơn ở cỡ 26px
      // đọc ra là cái thùng. Chênh lệch chiều cao là thứ khiến nó thành dãy
      // nhà. Và nó phải khác hẳn icon `home` (mái dốc + vòm cửa) vì hai thứ
      // này có thể đứng gần nhau.
      NpIcon.company => '<path stroke="$c" d="M5.4 20.4V7.4a1.7 1.7 0 0 1 1.7-1.7h5.1a1.7 1.7 0 0 1 1.7 1.7v13"/>'
          '<path stroke="$c" d="M13.9 11.6h3.6a1.7 1.7 0 0 1 1.7 1.7v7.1"/>'
          '<path stroke="$c" d="M3.4 20.4h17.2"/>'
          '<path stroke="$c" d="M8.3 9.5h2.4"/>'
          '<path stroke="$c" d="M8.3 13.6h2.4"/>'
          '<path stroke="$c" d="M16 15.8h1.3"/>',

      // Chuông. Phải là chuông chứ không mượn lại tia sét: tia sét đã mang
      // nghĩa "điểm uy tín" ở huy hiệu ngay cạnh trên trang chủ, và hai biểu
      // tượng giống hệt nhau đứng sát nhau với hai nghĩa khác nhau thì không
      // biểu tượng nào còn nghĩa gì.
      //
      // Thân chuông vẽ bằng hai cung nối vai thay vì một hình thang bo góc —
      // hình thang ở cỡ 21px trông như cái cốc úp ngược.
      NpIcon.bell => '<path stroke="$c" d="M6.4 16.6V11a5.6 5.6 0 0 1 11.2 0v5.6"/>'
          '<path stroke="$c" d="M4.9 16.6h14.2"/>'
          '<path stroke="$c" d="M10.2 19.6a2 2 0 0 0 3.6 0"/>'
          '<path stroke="$c" d="M12 5.4V3.6"/>',

      // Ngọn lửa cho chuỗi ngày — thay cho emoji 🔥, vốn là dấu hiệu rõ nhất
      // của giao diện dựng vội.
      NpIcon.flame => '<path stroke="$c" d="M12 3.4s4.6 3.7 4.6 8.2a4.6 4.6 0 0 1-9.2 0c0-1.6.8-2.9 1.6-3.8 0 1.4.8 2.3 1.6 2.3 1.1 0 1.4-1.2 1.4-2.4 0-1.6-.6-3-.6-3z"/>'
          '<path stroke="$c" d="M12 20.4a2.6 2.6 0 0 1-2.6-2.6c0-1.6 2.6-3.4 2.6-3.4s2.6 1.8 2.6 3.4a2.6 2.6 0 0 1-2.6 2.6z"/>',

      NpIcon.send => '<path stroke="$c" d="M20.6 3.6 10.9 13.3"/>'
          '<path stroke="$c" d="M20.6 3.6 14.4 20.6l-3.5-7.3-7.3-3.5z"/>',

      NpIcon.arrow => '<path stroke="$c" d="M4.5 12h15"/>'
          '<path stroke="$c" d="m13.4 5.9 6.1 6.1-6.1 6.1"/>',
    };
