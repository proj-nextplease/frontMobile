import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'opportunity.dart';
import '../../core/morph_icon.dart';
import 'saved_store.dart';

/// Nút lưu tin.
///
/// Tự nghe SavedStore nên mọi bản sao của cùng một tin — thẻ trong danh sách
/// và nút ở trang chi tiết — luôn hiện cùng trạng thái, không cần ai truyền
/// tin cho ai.
class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.item,
    required this.isGuest,
    this.onNeedSignIn,
    this.size = 22,
  });

  final Opportunity item;
  final bool isGuest;

  /// Khách bấm tim thì đưa về đăng nhập, vì lưu tin cần tài khoản. Không im
  /// lặng bỏ qua — người dùng sẽ tưởng nút hỏng.
  final VoidCallback? onNeedSignIn;

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final store = SavedStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saved = !isGuest && store.isSaved(item);
        final busy = store.isBusy(item.id);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : () => _tap(context, store),
          child: Padding(
            // Vùng chạm rộng hơn hẳn phần nhìn thấy: biểu tượng 22px là dưới
            // ngưỡng 44px mà cả iOS lẫn Android khuyến nghị cho mục tiêu chạm.
            padding: const EdgeInsets.all(Np.s3),
            child: AnimatedScale(
              scale: busy ? 0.85 : 1,
              duration: const Duration(milliseconds: 120),
              // Tim rỗng và tim đặc dùng CHUNG một đường, nên phép biến hình
              // ở đây chạy trên độ đặc chứ không trên toạ độ: màu dâng lên
              // từ trong ra. Lò xo nảy cho nó đi quá một chút rồi lắc về —
              // cú "bịch" nhỏ mà một nút tim cần có.
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: saved ? c.acidText : c.muted),
                duration: const Duration(milliseconds: 220),
                builder: (_, color, _) => MorphIconSwitch(
                  from: NpIcon.heart,
                  to: NpIcon.heartFill,
                  active: saved,
                  size: size,
                  color: color ?? c.muted,
                  spring: MorphSpring.bouncy,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _tap(BuildContext context, SavedStore store) async {
    if (isGuest) {
      onNeedSignIn?.call();
      return;
    }
    final err = await store.toggle(item);
    if (err == null || !context.mounted) return;

    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Np.rSm),
        ),
        content: Text(
          err,
          style: NpType.body.copyWith(fontSize: 14, color: Colors.white),
        ),
      ),
    );
  }
}
