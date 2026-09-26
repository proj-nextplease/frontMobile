import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design.dart';
import 'theme.dart';

/// Danh sách thông tin linh vật đồng bộ với Web.
class NpMascot {
  final String id;
  final String label;
  final String gender;
  final String description;

  const NpMascot({
    required this.id,
    required this.label,
    required this.gender,
    required this.description,
  });

  static const List<NpMascot> candidateMascots = [
    NpMascot(
      id: 'bald',
      label: 'Điềm tĩnh',
      gender: 'male',
      description: 'Chín chắn, thực tế, luôn kiên định với mục tiêu.',
    ),
    NpMascot(
      id: 'cap',
      label: 'Năng động',
      gender: 'male',
      description: 'Nhiệt huyết, thích thử thách mới và tốc độ.',
    ),
    NpMascot(
      id: 'ballerina',
      label: 'Thanh lịch',
      gender: 'female',
      description: 'Tỉ mỉ, sáng tạo, hướng tới sự hoàn hảo.',
    ),
    NpMascot(
      id: 'skater',
      label: 'Phóng khoáng',
      gender: 'female',
      description: 'Đột phá, tự do, sẵn sàng tạo nên lối đi riêng.',
    ),
  ];

  static const List<NpMascot> all = [
    ...candidateMascots,
    NpMascot(
      id: 'frog',
      label: 'NextPlease Frog',
      gender: 'neutral',
      description: 'Linh vật biểu tượng vui nhộn của hệ sinh thái.',
    ),
  ];

  static String resolveId(dynamic avatar) {
    if (avatar is Map) {
      final m = avatar['mascot'];
      if (m is String && all.any((x) => x.id == m)) return m;
      final g = avatar['gender'];
      if (g == 'male') return 'bald';
      if (g == 'female') return 'ballerina';
    }
    return 'ballerina';
  }

  static String directionsAsset(String id) => 'assets/mascots/$id-directions.webp';
  static String reactionsAsset(String id) => 'assets/mascots/$id-reactions.webp';
}

/// Widget vẽ 1 khung hình (3x3 grid) từ sprite sheet WebP của Mascot
class MascotSprite extends StatefulWidget {
  const MascotSprite({
    super.key,
    required this.assetPath,
    this.frameIndex = 4, // 0..8 (4 là nhìn thẳng)
    this.size = 120,
  });

  final String assetPath;
  final int frameIndex;
  final double size;

  @override
  State<MascotSprite> createState() => _MascotSpriteState();
}

class _MascotSpriteState extends State<MascotSprite> {
  ui.Image? _image;
  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(MascotSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _loadImage();
    }
  }

  void _loadImage() {
    final imageProvider = AssetImage(widget.assetPath);
    _imageStream?.removeListener(_listener!);
    _imageStream = imageProvider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() => _image = info.image);
      }
    });
    _imageStream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null && _imageStream != null) {
      _imageStream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
      );
    }

    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _SpriteSheetPainter(
        image: _image!,
        frameIndex: widget.frameIndex.clamp(0, 8),
      ),
    );
  }
}

class _SpriteSheetPainter extends CustomPainter {
  final ui.Image image;
  final int frameIndex;

  _SpriteSheetPainter({required this.image, required this.frameIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = image.width / 3.0;
    final frameHeight = image.height / 3.0;

    final col = frameIndex % 3;
    final row = frameIndex ~/ 3;

    final srcRect = Rect.fromLTWH(
      col * frameWidth,
      row * frameHeight,
      frameWidth,
      frameHeight,
    );

    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;

    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpriteSheetPainter old) =>
      old.image != image || old.frameIndex != frameIndex;
}

/// Mascot tương tác: chạm vào để đổi biểu cảm vui nhộn và nảy nhẹ!
class InteractiveMascot extends StatefulWidget {
  const InteractiveMascot({
    super.key,
    this.mascotId = 'ballerina',
    this.size = 120,
    this.enableTapReaction = true,
    this.onTap,
  });

  final String mascotId;
  final double size;
  final bool enableTapReaction;
  final VoidCallback? onTap;

  @override
  State<InteractiveMascot> createState() => _InteractiveMascotState();
}

class _InteractiveMascotState extends State<InteractiveMascot>
    with SingleTickerProviderStateMixin {
  bool _showReaction = false;
  int _reactionFrame = 0;
  int _directionFrame = 4; // Nhìn thẳng
  Timer? _reactionTimer;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  void _triggerReaction() {
    if (!widget.enableTapReaction) return;
    HapticFeedback.lightImpact();

    _reactionTimer?.cancel();
    _bounceController.reverse().then((_) => _bounceController.forward());

    setState(() {
      _showReaction = true;
      _reactionFrame = (_reactionFrame + 1) % 9; // Lần lượt qua các reaction
    });

    _reactionTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _showReaction = false);
      }
    });

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final asset = _showReaction
        ? NpMascot.reactionsAsset(widget.mascotId)
        : NpMascot.directionsAsset(widget.mascotId);
    final frame = _showReaction ? _reactionFrame : _directionFrame;

    return GestureDetector(
      onTap: _triggerReaction,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _bounceController,
        child: MascotSprite(
          assetPath: asset,
          frameIndex: frame,
          size: widget.size,
        ),
      ),
    );
  }
}

/// Component Empty State với linh vật biểu cảm thân thiện
class MascotEmptyState extends StatelessWidget {
  const MascotEmptyState({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.mascotId = 'frog',
    this.size = 130,
    this.padding = const EdgeInsets.symmetric(horizontal: Np.s6, vertical: Np.s10),
  });

  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String mascotId;
  final double size;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InteractiveMascot(
            mascotId: mascotId,
            size: size,
          ),
          const SizedBox(height: Np.s3),
          Text(
            title,
            style: NpType.title.copyWith(color: c.ink, fontSize: 17),
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: Np.s2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                description!,
                style: NpType.meta.copyWith(
                  color: c.muted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Np.s5),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Np.s5,
                  vertical: Np.s2 + 2,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceHi,
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  actionLabel!,
                  style: NpType.button.copyWith(
                    color: c.acidText,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bộ chọn 4 linh vật đại diện (Bald, Cap, Ballerina, Skater) đồng bộ với Web
class MascotPicker extends StatelessWidget {
  const MascotPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final activeMascot = NpMascot.candidateMascots.firstWhere(
      (m) => m.id == selectedId,
      orElse: () => NpMascot.candidateMascots.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Khung sân khấu linh vật đang chọn (Mascot Stage)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: Np.s5, vertical: Np.s6),
          decoration: BoxDecoration(
            color: c.surfaceHi,
            borderRadius: BorderRadius.circular(Np.rLg),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              InteractiveMascot(
                key: ValueKey(activeMascot.id),
                mascotId: activeMascot.id,
                size: 130,
              ),
              const SizedBox(height: Np.s3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    activeMascot.label,
                    style: NpType.title.copyWith(fontSize: 18, color: c.ink),
                  ),
                  const SizedBox(width: Np.s2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.acid.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(Np.rPill),
                    ),
                    child: Text(
                      'Linh vật của bạn',
                      style: NpType.meta.copyWith(
                        fontSize: 11,
                        color: c.acidText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Np.s1),
              Text(
                activeMascot.description,
                style: NpType.meta.copyWith(color: c.muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: Np.s4),
        Text(
          'Chọn 1 trong 4 linh vật đồng hành',
          style: NpType.label.copyWith(color: c.muted),
        ),
        const SizedBox(height: Np.s2),

        // Hàng 4 nút chọn 4 linh vật (Bald, Cap, Ballerina, Skater)
        Row(
          children: [
            for (final m in NpMascot.candidateMascots) ...[
              Expanded(
                child: _MascotOptionCard(
                  mascot: m,
                  isSelected: m.id == selectedId,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(m.id);
                  },
                ),
              ),
              if (m != NpMascot.candidateMascots.last)
                const SizedBox(width: Np.s2),
            ],
          ],
        ),
      ],
    );
  }
}

class _MascotOptionCard extends StatelessWidget {
  const _MascotOptionCard({
    required this.mascot,
    required this.isSelected,
    required this.onTap,
  });

  final NpMascot mascot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: Np.s3, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? c.acid.withValues(alpha: 0.12) : c.surfaceHi,
          borderRadius: BorderRadius.circular(Np.rMd),
          border: Border.all(
            color: isSelected ? c.acid : c.line,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: MascotSprite(
                assetPath: NpMascot.directionsAsset(mascot.id),
                frameIndex: 4, // Nhìn thẳng
                size: 48,
              ),
            ),
            const SizedBox(height: Np.s2),
            Text(
              mascot.label,
              style: NpType.meta.copyWith(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? c.acidText : c.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
