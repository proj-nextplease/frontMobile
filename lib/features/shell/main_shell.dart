import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../discussions/discussions_page.dart';
import '../home/home_page.dart';
import '../jobs/jobs_page.dart';
import '../jobs/search_page.dart';
import '../profile/profile_page.dart';

/// Khung chính của app: bốn tab, thanh điều hướng dưới đáy.
///
/// Dùng IndexedStack chứ không dựng lại màn hình mỗi lần đổi tab. Khác biệt
/// thấy được ngay: chuyển sang Hồ sơ rồi quay lại Cơ hội thì vị trí cuộn, tab
/// lọc đang chọn và dữ liệu đã tải vẫn còn nguyên — không gọi lại API.
///
/// Cái giá của IndexedStack là cả bốn màn hình đều được dựng từ đầu, kể cả tab
/// người dùng chưa bấm vào. Ở đây chấp nhận được vì chỉ có bốn, và mỗi cái chỉ
/// gọi một lượt API nhẹ.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.isGuest,
    required this.onSignIn,
    required this.onSignOut,
  });

  final bool isGuest;
  final VoidCallback onSignIn;
  final Future<void> Function() onSignOut;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 1;   // mở vào tab Cơ hội, không phải Trang chủ

  /// Chỉ MỘT biểu tượng cho mỗi tab, dùng chung cả hai trạng thái.
  ///
  /// Bản trước đổi sang biểu tượng tô đặc khi chọn, khiến tab đang chọn nặng
  /// hơn hẳn ba tab kia. Giữ nét viền và chỉ đổi màu thì thanh cân bằng hơn —
  /// đây chính là cách mẫu Upzi làm.
  static const _tabs = [
    (icon: Icons.home_outlined, label: 'Trang chủ'),
    (icon: Icons.work_outline_rounded, label: 'Cơ hội'),
    (icon: Icons.forum_outlined, label: 'Thảo luận'),
    (icon: Icons.person_outline_rounded, label: 'Hồ sơ'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: c.bg,
        // Thanh điều hướng NỔI đè lên nội dung thay vì đẩy nội dung lên. Nhờ
        // vậy danh sách trôi qua bên dưới nó, đúng như mẫu.
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            HomePage(
              isGuest: widget.isGuest,
              onSignIn: widget.onSignIn,
              onSeeAll: () => setState(() => _index = 1),
            ),
            JobsPage(isGuest: widget.isGuest, onSignIn: widget.onSignIn),
            const DiscussionsPage(),
            ProfilePage(
              isGuest: widget.isGuest,
              onSignIn: widget.onSignIn,
              onSignOut: widget.onSignOut,
            ),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          index: _index,
          tabs: _tabs,
          onTap: (i) => setState(() => _index = i),
          onSearch: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SearchPage(
                isGuest: widget.isGuest,
                onSignIn: widget.onSignIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh điều hướng NỔI: một viên thuốc tách khỏi mép, cạnh một nút tròn
/// riêng cho tìm kiếm.
///
/// Khác thanh dán sát đáy ở hai điểm, và cả hai đều có giá:
///   - Phải chừa lề và tự cộng vùng an toàn dưới, vì nó không còn dựa vào mép
///     màn hình nữa.
///   - Phải có BÓNG, nếu không nó trôi lẫn vào nội dung cuộn phía dưới.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.tabs,
    required this.onTap,
    required this.onSearch,
  });

  final int index;
  final List<({IconData icon, String label})> tabs;
  final ValueChanged<int> onTap;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bóng đậm hơn ở chế độ sáng. Trên nền tối, bóng đen gần như vô hình nên
    // phải dựa vào viền sáng mờ thay thế.
    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
        blurRadius: 22,
        offset: const Offset(0, 6),
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Np.s4, 0, Np.s4,
        Np.s3 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Np.rPill),
                border: Border.all(color: c.line),
                boxShadow: shadow,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: GestureDetector(
                        // opaque để cả ô đều bấm được, không chỉ riêng chỗ có
                        // biểu tượng và chữ.
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: _Item(tab: tabs[i], selected: i == index),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Np.s3),
          GestureDetector(
            onTap: onSearch,
            child: Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // Trắng, không phải lime đặc. Nút tròn lime đấu với nút hành
                // động chính (cũng lime) ở mọi màn hình, và người dùng mất
                // manh mối đâu mới là việc cần làm. Thanh điều hướng là hạ
                // tầng, không phải lời kêu gọi.
                color: c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.line),
                boxShadow: shadow,
              ),
              child: Icon(Icons.search_rounded, size: 25, color: c.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.tab, required this.selected});

  final ({IconData icon, String label}) tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ô bo tròn nền nhạt sau biểu tượng là dấu hiệu tab đang chọn. Nền
        // nhạt chứ không đặc: nền đặc màu acid sẽ đấu với nút tìm kiếm ngay
        // bên cạnh, vốn cũng màu acid.
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
            // 0.10 chứ không 0.14: ô này chỉ để gợi ý, việc báo tab nào đang
            // chọn đã do màu icon và màu chữ đảm nhiệm rồi.
            color: selected
                ? c.acidText.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(Np.rSm + 2),
          ),
          child: Icon(
            tab.icon,
            size: 22,
            color: selected ? c.acidText : c.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tab.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: NpType.meta.copyWith(
            fontSize: 10,
            height: 1.1,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? c.acidText : c.muted,
          ),
        ),
      ],
    );
  }
}
