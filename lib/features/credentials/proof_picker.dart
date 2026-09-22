import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';

/// Chọn và nén ảnh minh chứng.
///
/// ─── Vì sao phải nén, không phải tuỳ chọn ────────────────────────────────
/// Ảnh từ camera điện thoại là 3–8 MB. Base64 phình thêm khoảng 33%. Sáu ảnh
/// là vài chục megabyte nhét vào MỘT cột JSONB, đi qua một request duy nhất.
/// Backend hiện KHÔNG chặn dung lượng, nên nếu client không nén thì nó sẽ
/// nhận và lưu — rồi mọi lần đọc hồ sơ sau đó đều kéo về ngần ấy dữ liệu.
///
/// maxWidth 1280 + imageQuality 70 cho ra khoảng 150–400 KB mỗi ảnh, vẫn đọc
/// được chữ trên giấy chứng nhận chụp gần.
class ProofPicker extends StatelessWidget {
  const ProofPicker({
    super.key,
    required this.images,
    required this.onChanged,
  });

  /// Data URL base64, đúng định dạng mà web đang lưu.
  final List<String> images;
  final ValueChanged<List<String>> onChanged;

  /// Giới hạn của backend (serializeImages cắt ở 6). Chặn ở đây để người dùng
  /// không mất công chọn ảnh thứ bảy rồi thấy nó biến mất.
  static const _max = 6;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final shots = source == ImageSource.camera
          ? [
              if (await picker.pickImage(
                    source: source,
                    maxWidth: 1280,
                    imageQuality: 70,
                  )
                  case final XFile f)
                f,
            ]
          : await picker.pickMultiImage(maxWidth: 1280, imageQuality: 70);

      if (shots.isEmpty) return;

      final next = [...images];
      for (final f in shots) {
        if (next.length >= _max) break;
        final bytes = await f.readAsBytes();
        next.add('data:image/jpeg;base64,${base64Encode(bytes)}');
      }
      onChanged(next);
    } on Exception catch (e) {
      // Người dùng từ chối quyền, hoặc máy không có camera. Nói ra thay vì
      // để nút bấm không phản ứng gì.
      if (!context.mounted) return;
      final c = Np.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: c.surfaceHi,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Np.rSm),
          side: BorderSide(color: c.line),
        ),
        content: Text('Không mở được ảnh. ${e.runtimeType}',
            style: NpType.body.copyWith(fontSize: 14, color: c.ink)),
      ));
    }
  }

  void _remove(int i) => onChanged([...images]..removeAt(i));

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final full = images.length >= _max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) ...[
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: Np.s2),
              itemBuilder: (_, i) => _Thumb(
                data: images[i],
                onRemove: () => _remove(i),
              ),
            ),
          ),
          const SizedBox(height: Np.s3),
        ],

        Row(
          children: [
            Expanded(
              child: _PickButton(
                icon: Icons.photo_camera_rounded,
                label: 'Chụp ảnh',
                enabled: !full,
                onTap: () => _pick(context, ImageSource.camera),
              ),
            ),
            const SizedBox(width: Np.s2),
            Expanded(
              child: _PickButton(
                icon: Icons.photo_library_rounded,
                label: 'Chọn từ máy',
                enabled: !full,
                onTap: () => _pick(context, ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: Np.s2),
        Text(
          full
              ? 'Đã đủ $_max ảnh — xoá bớt nếu muốn thay.'
              : '${images.length}/$_max ảnh. Ảnh được nén lại trước khi gửi.',
          style: NpType.meta.copyWith(fontSize: 12, color: c.muted),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.data, required this.onRemove});
  final String data;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final comma = data.indexOf(',');
    final bytes = comma == -1 ? null : _decode(data.substring(comma + 1));

    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Np.rSm),
            child: bytes == null
                ? Container(width: 92, height: 92, color: c.surfaceHi)
                : Image.memory(bytes, width: 92, height: 92, fit: BoxFit.cover),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              // Vùng chạm 30px cho một dấu × nhỏ: nhỏ hơn thì trên ảnh vuông
              // 92px người dùng rất dễ bấm trượt vào chính ảnh.
              child: SizedBox(
                width: 30,
                height: 30,
                child: Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.band,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bg, width: 1.5),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 13, color: c.onBand),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Uint8List? _decode(String b64) {
    try {
      return base64Decode(b64);
    } on FormatException {
      return null;
    }
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final tint = enabled ? c.ink : c.faint;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Np.rMd),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: tint),
            const SizedBox(width: Np.s2),
            Text(label,
                style: NpType.meta.copyWith(
                  fontSize: 13.5,
                  color: tint,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
