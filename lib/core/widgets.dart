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
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;
  final IconData? icon;
  final bool expand;

  @override
  State<AcidButton> createState() => _AcidButtonState();
}

class _AcidButtonState extends State<AcidButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final pressed = _down && !widget.busy;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        if (!widget.busy) widget.onTap();
      },
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
            color: Np.acid,
            borderRadius: BorderRadius.circular(Np.rMd),
            // Quầng sáng tắt lúc bấm — nút "áp xuống mặt phẳng".
            boxShadow: pressed || widget.busy ? null : Np.acidGlow,
          ),
          child: widget.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Np.onAcid),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.label,
                        style: NpType.button.copyWith(color: Np.onAcid)),
                    if (widget.icon != null) ...[
                      const SizedBox(width: Np.s2),
                      Icon(widget.icon, color: Np.onAcid, size: 18),
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
/// Không tô nền cho chip: một dãy chip có nền trên nền tối tạo ra quá nhiều
/// mảng sáng cạnh nhau, và mắt không còn biết đâu là thông tin chính. Viền mờ
/// đủ để gom nhóm mà không tranh chấp với nội dung.
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, this.icon, this.tone});

  final String label;
  final IconData? icon;

  /// Chỉ truyền khi chip mang nghĩa đặc biệt (phần thưởng, trạng thái).
  /// Mặc định trung tính.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = tone ?? Np.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Np.s3, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Np.rPill),
        border: Border.all(
          color: tone == null ? Np.line : c.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: NpType.meta.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: tone == null ? Np.muted : c,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn mục nhỏ viết hoa, có gạch acid ngắn dẫn trước.
///
/// Gạch dẫn là cách rẻ nhất để một nhãn 11px không bị trôi mất trên nền tối,
/// mà không phải tăng cỡ chữ hay tô cả dòng thành màu.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 14,
            height: 2,
            decoration: BoxDecoration(
              color: Np.acid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: Np.s2),
          Text(text.toUpperCase(), style: NpType.label),
        ],
      );
}
