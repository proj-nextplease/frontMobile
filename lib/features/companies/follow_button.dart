import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../core/morph_icon.dart';
import '../../core/np_icons.dart';
import 'companies_store.dart';

/// Nút theo dõi/bỏ theo dõi. Tự nghe kho nên đặt ở đâu cũng đồng bộ.
class FollowButton extends StatefulWidget {
  const FollowButton({super.key, required this.companyId, this.compact = false});

  final String companyId;

  /// Bản nhỏ dùng trong danh sách; bản lớn dùng ở trang chi tiết.
  final bool compact;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  final _store = CompaniesStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_sync);
  }

  @override
  void dispose() {
    _store.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  Future<void> _tap() async {
    final err = await _store.toggle(widget.companyId);
    if (err != null && mounted) {
      final c = Np.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: c.danger,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
        content: Text(err,
            style: NpType.body.copyWith(fontSize: 14, color: Colors.white)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final on = _store.isFollowing(widget.companyId);
    final busy = _store.pending.contains(widget.companyId);

    return GestureDetector(
      onTap: busy ? null : _tap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? Np.s3 : Np.s5,
          vertical: widget.compact ? Np.s2 : Np.s3,
        ),
        decoration: BoxDecoration(
          // Đang theo dõi thì là nút VIỀN, chưa theo dõi thì nút ĐẶC. Trạng
          // thái đang bật không cần kêu gọi bấm nữa.
          color: on ? Colors.transparent : c.acid,
          borderRadius: BorderRadius.circular(Np.rPill),
          border: Border.all(color: on ? c.line : c.acid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cộng → tích: cặp biến hình chủ lực. Hai dấu này khác hẳn nhau
            // về hình, nên ở đây phép biến hình chạy trên TOẠ ĐỘ — nét ngang
            // của dấu cộng duỗi thành cạnh dài của dấu tích, nét dọc co lại.
            MorphIconSwitch(
              from: NpIcon.plus,
              to: NpIcon.check,
              active: on,
              size: widget.compact ? 14 : 16,
              color: on ? c.muted : c.onAcid,
              strokeWidth: 2.4,
            ),
            SizedBox(width: widget.compact ? Np.s1 + 2 : Np.s2),
            Text(
              on ? 'Đang theo dõi' : 'Theo dõi',
              style: NpType.button.copyWith(
                fontSize: widget.compact ? 13 : 15,
                color: on ? c.muted : c.onAcid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
