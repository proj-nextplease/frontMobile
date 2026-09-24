import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bộ biểu tượng của nextplease, dựng trên hình học của Lucide.
///
/// ─── Vì sao Lucide ──────────────────────────────────────────────────────
/// Trước đây bộ này vẽ tay, cốt để tránh Icons.* của Material — thứ mà mọi
/// app Flutter dựng nhanh đều dùng, nên người dùng nhận ra ngay dù không gọi
/// tên được. Lý do đó vẫn đúng, nhưng kết luận thì không: tự vẽ nghĩa là tự
/// gánh việc cân từng nét, và bộ vẽ tay cũ có chỗ lệch trọng lượng thấy rõ
/// khi đặt cạnh nhau.
///
/// Lucide giải đúng bài toán đó: hình học đặt trên lưới 24×24 nhất quán, nét
/// 2px, đầu và khớp bo tròn, và mỗi icon đã được cân với cả bộ. Nó cũng là
/// bộ mà morphicons dùng — nghĩa là nếu sau này thêm hiệu ứng biến hình thì
/// các cặp icon đã sẵn cùng một hệ toạ độ.
///
/// Quy tắc giữ nguyên ba điều: khung 24×24, nét 2px bo tròn, hình học đơn
/// giản. Icon nào Lucide không có thì dựng theo đúng ba quy tắc đó.
///
/// ─── Giấy phép ──────────────────────────────────────────────────────────
/// Dữ liệu đường vẽ lấy từ Lucide, phát hành theo giấy phép ISC:
///
///   Copyright (c) 2026 Lucide Icons and Contributors
///
///   Permission to use, copy, modify, and/or distribute this software for
///   any purpose with or without fee is hereby granted, provided that the
///   above copyright notice and this permission notice appear in all copies.
///
///   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
///   WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
///   WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR
///   BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES
///   OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
///   WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
///   ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
///   SOFTWARE.
///
/// Bản đầy đủ nằm ở LICENSE-lucide tại gốc dự án.
enum NpIcon {
  home,
  jobs,
  chat,
  person,
  search,
  heart,
  heartFill,
  bolt,
  bell,
  flame,
  send,
  arrow,
  company,
  wallet,
  crown,
  plus,
  check,
  close,
  star,
  starFill,
}

class NpIco extends StatelessWidget {
  const NpIco(this.icon, {super.key, this.size = 22, required this.color});

  final NpIcon icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    return SvgPicture.string(
      _svg(icon, hex),
      width: size,
      height: size,
    );
  }
}

String _svg(NpIcon i, String c) {
  // stroke-width 2 là mặc định của Lucide và là thứ giữ cả bộ cân nhau. Đổi
  // riêng một icon sang nét khác là cách nhanh nhất làm nó nhảy ra khỏi hàng.
  final open = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke="$c" stroke-width="2" stroke-linecap="round" '
      'stroke-linejoin="round">';
  return '$open${_body(i, c)}</svg>';
}

String _body(NpIcon i, String c) => switch (i) {
      // house
      NpIcon.home => '<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/>'
          '<path d="M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',

      // briefcase-business
      NpIcon.jobs => '<path d="M12 12h.01"/>'
          '<path d="M16 6V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/>'
          '<path d="M22 13a18.15 18.15 0 0 1-20 0"/>'
          // rect gốc của Lucide viết lại thành path: bộ biến hình lấy mẫu
          // theo đường, nên một icon còn <rect> hay <circle> sẽ bị mất hình
          // đó mà không báo gì.
          '<path d="M4 6h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z"/>',

      // message-circle
      NpIcon.chat => '<path d="M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719"/>',

      // user
      NpIcon.person => '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/>'
          '<path d="M8 7a4 4 0 1 0 8 0 4 4 0 1 0-8 0z"/>',

      // search
      NpIcon.search => '<path d="m21 21-4.34-4.34"/>'
          '<path d="M3 11a8 8 0 1 0 16 0 8 8 0 1 0-16 0z"/>',

      NpIcon.heart => '<path d="M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5"/>',

      // Lucide không có tim đặc. Dùng ĐÚNG đường của tim rỗng rồi tô thêm —
      // vẽ một hình riêng thì hai trạng thái của cùng một nút sẽ lệch nhau
      // vài pixel và mắt bắt được cú giật đó khi bấm lưu tin.
      NpIcon.heartFill => '<path fill="$c" d="M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5"/>',

      // zap — điểm uy tín và EXP
      NpIcon.bolt => '<path d="M15.914 4a1.5 1.5 0 0 0-2.474-1.561l-9 9A1.5 1.5 0 0 0 5.5 14h4.002a.5.5 0 0 1 .471.666L8.086 20a1.5 1.5 0 0 0 2.475 1.56l9-9A1.5 1.5 0 0 0 18.5 10h-3.997a.5.5 0 0 1-.472-.667z"/>',

      NpIcon.bell => '<path d="M10.268 21a2 2 0 0 0 3.464 0"/>'
          '<path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>',

      // flame — chuỗi ngày liên tiếp, thay cho emoji 🔥
      NpIcon.flame => '<path d="M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4"/>',

      NpIcon.send => '<path d="M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z"/>'
          '<path d="m21.854 2.147-10.94 10.939"/>',

      // arrow-right
      NpIcon.arrow => '<path d="M5 12h14"/>'
          '<path d="m12 5 7 7-7 7"/>',

      // building-2 — dùng khi tổ chức không có logo.
      //
      // Vì sao không để chữ cái đầu: "CT" cho "CTY KT" không nói được gì, và
      // một danh sách toàn ô chữ hai ký tự trông như bảng mã.
      NpIcon.company => '<path d="M10 12h4"/>'
          '<path d="M10 8h4"/>'
          '<path d="M14 21v-3a2 2 0 0 0-4 0v3"/>'
          '<path d="M6 10H4a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-2"/>'
          '<path d="M6 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16"/>',

      NpIcon.wallet => '<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1"/>'
          '<path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>',

      NpIcon.crown => '<path d="M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L21.183 5.5a.5.5 0 0 1 .798.519l-2.834 10.246a1 1 0 0 1-.956.734H5.81a1 1 0 0 1-.957-.734L2.02 6.02a.5.5 0 0 1 .798-.519l4.276 3.664a1 1 0 0 0 1.516-.294z"/>'
          '<path d="M5 21h14"/>',

      // plus / check / x — ba icon của các nút đổi trạng thái. plus → check
      // là cặp biến hình kinh điển (nút theo dõi), nên chúng phải cùng bộ.
      NpIcon.plus => '<path d="M5 12h14"/><path d="M12 5v14"/>',

      NpIcon.check => '<path d="M20 6 9 17l-5-5"/>',

      NpIcon.close => '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',

      // Sao cho đánh giá. Hai bản dùng CHUNG một đường, chỉ khác phần tô —
      // cùng lý do với cặp tim: sao rỗng và sao đặc đứng cạnh nhau trong một
      // hàng năm cái, lệch một pixel là mắt thấy ngay.
      NpIcon.star => '<path d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"/>',

      NpIcon.starFill => '<path fill="$c" d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"/>',
    };

/// Dữ liệu đường THÔ của một icon — chỉ các chuỗi `d`, không kèm lớp bọc SVG.
///
/// Bộ biến hình cần toạ độ để lấy mẫu và nội suy, mà từ một chuỗi SVG hoàn
/// chỉnh thì phải bóc ngược ra bằng chuỗi ký tự. Giữ một nguồn ở đây và để
/// cả hai nơi cùng đọc thì không có gì để lệch.
List<String> npIconPaths(NpIcon i) => _pathRe
    .allMatches(_body(i, '#000000'))
    .map((m) => m.group(1)!)
    .toList();

final _pathRe = RegExp(r'<path[^>]*\sd="([^"]*)"');

/// Icon này vẽ đặc hay chỉ có nét.
bool npIconIsFilled(NpIcon i) =>
    i == NpIcon.heartFill || i == NpIcon.starFill;
