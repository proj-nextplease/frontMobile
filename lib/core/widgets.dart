import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'design.dart';

/// Nút chính: nền acid phẳng, chữ mực.
///
/// Phẳng chứ không gradient. Một màu bão hoà cao đặt đúng chỗ luôn tự tin hơn
/// hai màu chuyển sắc — và gradient tím→hồng là thứ bị dùng nhiều nhất thập kỷ
/// qua, nên nó đọc ra là "mẫu có sẵn" chứ không phải một quyết định.
class AcidButton extends StatefulWidget {
  const AcidButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.icon,
    this.expand = true,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;
  final IconData? icon;
  final bool expand;

  /// Tắt thì nút XÁM và không ăn cú chạm.
  ///
  /// Phải có thật, không được giả bằng cách truyền `onTap: () {}`: nút vẫn
  /// xanh, vẫn lún xuống khi bấm, nhưng không xảy ra gì — người dùng bấm vài
  /// lần rồi kết luận app hỏng. Đúng lỗi đã xảy ra ở màn đăng ký.
  final bool enabled;

  @override
  State<AcidButton> createState() => _AcidButtonState();
}

class _AcidButtonState extends State<AcidButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final live = widget.enabled && !widget.busy;
    final pressed = _down && live;

    return GestureDetector(
      onTapDown: live ? (_) => setState(() => _down = true) : null,
      onTapCancel: live ? () => setState(() => _down = false) : null,
      onTapUp: live
          ? (_) {
              setState(() => _down = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          height: 56,
          width: widget.expand ? double.infinity : null,
          padding: widget.expand
              ? null
              : const EdgeInsets.symmetric(horizontal: Np.s6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.enabled ? c.acid : c.surface,
            borderRadius: BorderRadius.circular(Np.rMd),
            border: widget.enabled ? null : Border.all(color: c.line),
            // Quầng sáng tắt lúc bấm — nút "áp xuống mặt phẳng".
            boxShadow: pressed || widget.busy || !widget.enabled
                ? null
                : Np.glow(c, isDark: isDark),
          ),
          child: widget.busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: c.onAcid),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.label,
                        style: NpType.button.copyWith(
                            color: widget.enabled ? c.onAcid : c.faint)),
                    if (widget.icon != null) ...[
                      const SizedBox(width: Np.s2),
                      Icon(widget.icon,
                          color: widget.enabled ? c.onAcid : c.faint,
                          size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Chip thông tin: viền mờ, không nền.
///
/// Không tô nền cho chip: một dãy chip có nền tạo ra quá nhiều mảng cạnh nhau
/// và mắt không còn biết đâu là thông tin chính. Viền mờ đủ để gom nhóm mà
/// không tranh chấp với nội dung.
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, this.icon, this.accent = false});

  final String label;
  final IconData? icon;

  /// Bật khi chip mang nghĩa đặc biệt. Mặc định trung tính — tô màu hết là
  /// quay lại lỗi "quá nhiều màu".
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final fg = accent ? c.acidText : c.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Np.s3, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Np.rPill),
        border: Border.all(
          color: accent ? fg.withValues(alpha: 0.45) : c.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: NpType.meta.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn mục nhỏ viết hoa, có gạch acid ngắn dẫn trước.
///
/// Gạch dẫn là cách rẻ nhất để một nhãn 11px không bị trôi mất, mà không phải
/// tăng cỡ chữ hay tô cả dòng thành màu.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Row(
      children: [
        Container(
          width: 14,
          height: 2,
          decoration: BoxDecoration(
            color: c.acidText,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: Np.s2),
        Text(text.toUpperCase(),
            style: NpType.label.copyWith(color: c.muted)),
      ],
    );
  }
}

/// Logo của tổ chức.
///
/// Trước đây nằm private trong opportunity_card.dart. Tách ra vì trang Đơn đã
/// nộp cũng cần đúng thứ này, và chép lần hai là chép luôn cả phần xử lý
/// data URL — thứ dễ quên nhất.
///
/// Xử lý được BA dạng: http(s), data URL base64 (bản web lưu ảnh tải lên theo
/// kiểu đó, mà Image.network KHÔNG tải được và thất bại im lặng), và không có
/// gì (rơi về chữ cái đầu).
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({
    super.key,
    required this.url,
    required this.name,
    this.size = 26,
  });

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final radius = size * 0.27;
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? 'NP'
        : trimmed.substring(0, trimmed.length.clamp(1, 2)).toUpperCase();

    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceHi,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: c.line),
          ),
          child: Text(
            initials,
            style: NpType.label.copyWith(
              fontSize: size * 0.36,
              color: c.muted,
              letterSpacing: 0,
            ),
          ),
        );

    final src = url;
    if (src == null || src.isEmpty) return fallback();

    final Widget image;
    if (src.startsWith('data:')) {
      final comma = src.indexOf(',');
      final bytes = comma == -1 ? null : _tryDecodeBase64(src.substring(comma + 1));
      if (bytes == null) return fallback();
      image = Image.memory(bytes,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback());
    } else {
      image = Image.network(src,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
  }
}

/// Giải mã base64; chuỗi hỏng thì trả null để nơi gọi dùng phương án dự phòng
/// thay vì ném lỗi ra giữa lúc dựng giao diện.
Uint8List? _tryDecodeBase64(String b64) {
  try {
    return base64Decode(b64);
  } on FormatException {
    return null;
  }
}
