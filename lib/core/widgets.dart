import 'package:flutter/material.dart';

import 'design.dart';

/// Nút chính: nền gradient, bo lớn, bóng phát sáng cùng tông.
///
/// Phản hồi khi bấm là THU NHỎ nhẹ (0.97) chứ không trượt như bản sticker cũ:
/// trượt hợp với nút "dán trên giấy", còn với nút gradient phát sáng thì thu
/// nhỏ đọc ra là "bị ấn xuống" tự nhiên hơn.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;
  final IconData? icon;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        if (!widget.busy) widget.onTap();
      },
      child: AnimatedScale(
        scale: _down && !widget.busy ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: Np.brand,
            borderRadius: BorderRadius.circular(Np.rLg),
            boxShadow: widget.busy ? null : Np.glow,
          ),
          child: widget.busy
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (widget.icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(widget.icon, color: Colors.white, size: 19),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Chữ tô gradient. Dùng ShaderMask vì Flutter không cho gán gradient thẳng
/// vào TextStyle.
///
/// Chỉ dùng cho MỘT cụm từ trên mỗi màn hình. Tô gradient cho nhiều chỗ thì
/// không còn chỗ nào là điểm nhấn nữa.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (bounds) => Np.brand.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        ),
        // Màu phải là trắng đục thì shader mới hiện đúng — đây là yêu cầu của
        // chế độ hoà trộn srcIn, không phải lựa chọn thẩm mỹ.
        child: Text(text, style: style.copyWith(color: Colors.white)),
      );
}

/// Chip nhỏ: nền nhạt cùng tông, không viền.
class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.label,
    this.tone,
    this.icon,
  });

  final String label;

  /// Bỏ trống thì chip trung tính. Đa số chip nên trung tính — tô màu hết là
  /// quay lại lỗi "quá nhiều màu".
  final Color? tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = tone ?? Np.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: Np.softChip(c),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13.5, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone == null ? Np.ink.withValues(alpha: 0.78) : c,
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
