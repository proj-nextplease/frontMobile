import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../discussions/discussions_page.dart';
import '../home/home_page.dart';
import '../jobs/jobs_page.dart';
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

  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Trang chủ'),
    (icon: Icons.work_outline_rounded, active: Icons.work_rounded, label: 'Cơ hội'),
    (icon: Icons.forum_outlined, active: Icons.forum_rounded, label: 'Thảo luận'),
    (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'Hồ sơ'),
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
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.tabs,
    required this.onTap,
  });

  final int index;
  final List<({IconData icon, IconData active, String label})> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: GestureDetector(
                    // opaque để cả ô đều bấm được, không chỉ riêng chỗ có
                    // biểu tượng và chữ.
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: _Item(
                      tab: tabs[i],
                      selected: i == index,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.tab, required this.selected});

  final ({IconData icon, IconData active, String label}) tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    // Tab đang chọn dùng màu MỰC chứ không phải acid. Acid ở đây sẽ đấu với
    // nút chính màu acid trên cùng màn hình, và người dùng mất manh mối đâu là
    // hành động chính.
    final color = selected ? c.ink : c.muted;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Gạch acid ngắn phía trên là dấu hiệu tab đang chọn — đủ nổi mà không
        // tô cả biểu tượng thành màu.
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 2,
          width: selected ? 18 : 0,
          decoration: BoxDecoration(
            color: c.acidText,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 7),
        Icon(selected ? tab.active : tab.icon, size: 22, color: color),
        const SizedBox(height: 3),
        Text(
          tab.label,
          style: NpType.meta.copyWith(
            fontSize: 10.5,
            height: 1.1,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}
