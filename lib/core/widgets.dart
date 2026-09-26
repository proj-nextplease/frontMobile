import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'design.dart';
import 'np_icons.dart';

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

    // Không có logo thì dùng biểu tượng TOÀ NHÀ, không phải chữ cái đầu.
    // "CT" cho "CTY KT" không nói được gì, và một danh sách toàn ô hai ký tự
    // trông như bảng mã. Hình vẽ nói ngay "đây là một tổ chức".
    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceHi,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: c.line),
          ),
          child: NpIco(NpIcon.company, size: size * 0.62, color: c.muted),
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

/// Dòng chữ chạy ngang vô tận mượt mà (Infinite Marquee Ticker).
///
/// Chạy liên tục từ phải sang trái mượt mà và liền mạch không ngắt quãng,
/// kèm dải mờ nhẹ ở 2 cạnh mép.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 30.0, // pixels per second
    this.separator = '   ✦   ',
  });

  final String text;
  final TextStyle style;
  final double velocity;
  final String separator;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _singleWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _singleWidth = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _calculateAndStart(double textWidth) {
    if (textWidth <= 0) return;
    if (_singleWidth != textWidth) {
      _singleWidth = textWidth;
      final durationMs =
          ((textWidth / widget.velocity) * 1000).toInt().clamp(1000, 60000);
      _controller.duration = Duration(milliseconds: durationMs);
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemText = '${widget.text}${widget.separator}';
    final textSpan = TextSpan(text: itemText, style: widget.style);
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final itemWidth = tp.width;
    _calculateAndStart(itemWidth);

    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.03, 0.94, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: ClipRect(
        child: SizedBox(
          height: tp.height + 4,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = -(_controller.value * itemWidth);
              return OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: double.infinity,
                child: Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(itemText, style: widget.style, maxLines: 1),
                      Text(itemText, style: widget.style, maxLines: 1),
                      Text(itemText, style: widget.style, maxLines: 1),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
