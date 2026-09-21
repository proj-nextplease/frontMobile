import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../discussions/discussions_page.dart';
import '../home/home_page.dart';
import '../jobs/jobs_page.dart';
import '../jobs/saved_store.dart';
import '../jobs/search_page.dart';
import '../jobs/seen_store.dart';
import '../profile/gamification_store.dart';
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

  /// Thanh trượt đi khi cuộn xuống, về khi cuộn lên. Trả lại ~110px chiều cao
  /// cho danh sách ở đúng lúc người dùng đang đọc.
  bool _navVisible = true;

  @override
  void initState() {
    super.initState();
    SeenStore.instance.load();
    // Mở app vào thẳng tab Cơ hội nên phải đánh dấu đã xem ngay, nếu không
    // chấm báo sẽ hiện trên chính tab người dùng đang đứng.
    SeenStore.instance.markSeen();
  }

  void _onTab(int i) {
    setState(() => _index = i);
    if (i == 1) SeenStore.instance.markSeen();
  }

  /// Chỉ phản ứng với cú cuộn do NGƯỜI DÙNG kéo (UserScrollNotification).
  /// Dùng ScrollNotification chung thì thanh sẽ giật mỗi lần danh sách tự
  /// cuộn — ví dụ lúc bàn phím đẩy nội dung lên.
  bool _onScroll(UserScrollNotification n) {
    final down = n.direction == ScrollDirection.reverse;
    final up = n.direction == ScrollDirection.forward;
    if (down && _navVisible) setState(() => _navVisible = false);
    if (up && !_navVisible) setState(() => _navVisible = true);
    return false;
  }

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

  /// Hành động của nút tròn, đổi theo tab đang đứng.
  ///
  /// Ba trong bốn hành động CHƯA có trong app (bộ lọc, viết bài, sửa hồ sơ) —
  /// chúng hiện thông báo nói thẳng là phải dùng website. Để nút im lặng
  /// không làm gì thì người dùng tưởng app hỏng.
  static const _actions = [
    (icon: Icons.search_rounded, label: 'Tìm kiếm'),
    (icon: Icons.tune_rounded, label: 'Bộ lọc'),
    (icon: Icons.edit_outlined, label: 'Viết bài'),
    (icon: Icons.manage_accounts_outlined, label: 'Sửa hồ sơ'),
  ];

  void _runAction() {
    if (_index == 0 || _index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SearchPage(
            isGuest: widget.isGuest,
            onSignIn: widget.onSignIn,
          ),
        ),
      );
      return;
    }
    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.surfaceHi,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
            Np.gutter, 0, Np.gutter, Np.navInset),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Np.rSm),
          side: BorderSide(color: c.line),
        ),
        content: Text(
          '${_actions[_index].label} chưa có trong app. '
          'Tạm thời làm trên website nhé.',
          style: NpType.body.copyWith(fontSize: 14, color: c.ink),
        ),
      ),
    );
  }

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
        body: NotificationListener<UserScrollNotification>(
          onNotification: _onScroll,
          child: IndexedStack(
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
        ),
        bottomNavigationBar: AnimatedSlide(
          offset: _navVisible ? Offset.zero : const Offset(0, 1.4),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _BottomBar(
            index: _index,
            tabs: _tabs,
            action: _actions[_index],
            isGuest: widget.isGuest,
            onTap: _onTab,
            onAction: _runAction,
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
/// Thanh điều hướng NỔI: viên thuốc tách khỏi mép, cạnh một nút tròn riêng.
///
/// Khác thanh dán sát đáy ở ba điểm, và cả ba đều phải xử lý:
///   - extendBody để nội dung trôi bên dưới → mọi danh sách phải chừa
///     Np.navInset ở đáy.
///   - Tự cộng vùng an toàn dưới, vì nó không dựa vào mép màn hình nữa.
///   - Phải có bóng, nếu không nó trôi lẫn vào nội dung cuộn.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.tabs,
    required this.action,
    required this.isGuest,
    required this.onTap,
    required this.onAction,
  });

  final int index;
  final List<({IconData icon, String label})> tabs;
  final ({IconData icon, String label}) action;
  final bool isGuest;
  final ValueChanged<int> onTap;
  final VoidCallback onAction;

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
              // Cắt theo hình viên thuốc để vạch EXP ở mép trên bo theo góc,
              // không thò ra ngoài hai đầu.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Np.rPill),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: GestureDetector(
                              // opaque để cả ô đều bấm được, không chỉ riêng
                              // chỗ có biểu tượng và chữ.
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTap(i),
                              child: _Item(
                                tab: tabs[i],
                                selected: i == index,
                                slot: i,
                                isGuest: isGuest,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!isGuest)
                      const Positioned(
                        left: 0, right: 0, top: 0,
                        child: _ExpLine(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Np.s3),
          GestureDetector(
            onTap: onAction,
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // Trắng, không phải lime đặc. Nút tròn lime đấu với nút hành
                // động chính (cũng lime) ở mọi màn hình.
                color: c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.line),
                boxShadow: shadow,
              ),
              // Icon đổi theo tab. Hoạt hoạ xoay + mờ dần để người dùng THẤY
              // nó vừa đổi — nút đổi nghĩa mà đổi lặng lẽ là nguồn gốc của
              // việc bấm nhầm.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Icon(
                  action.icon,
                  key: ValueKey(action.icon),
                  size: 25,
                  color: c.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vạch EXP chạy dọc mép trên viên thuốc.
///
/// Đây là lý do đáng giá nhất để thanh điều hướng tồn tại ngoài việc chuyển
/// tab: nó là bề mặt DUY NHẤT luôn hiện, mà lời hứa của sản phẩm — mỗi việc
/// hoàn thành là một minh chứng — lại đang bị giấu trong một tab hiếm ai mở.
///
/// Mảnh 3px và chỉ chiếm mép trên: nó là thông tin nền, không phải thứ tranh
/// chấp với bốn tab bên dưới.
class _ExpLine extends StatelessWidget {
  const _ExpLine();

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return ListenableBuilder(
      listenable: GamificationStore.instance,
      builder: (context, _) {
        final g = GamificationStore.instance;
        if (!g.loaded || g.expForNextLevel <= 0) {
          return const SizedBox.shrink();
        }
        // Vẽ cả RÃNH nền, không chỉ phần đã đầy. Người dùng mới có 0 EXP thì
        // phần đầy rộng 0% và vô hình — nhìn ra y hệt lúc chưa tải được dữ
        // liệu. Có rãnh thì họ thấy ngay "đây là một thang đo, mình đang ở
        // vạch xuất phát".
        return Container(
          height: 3,
          color: c.acidText.withValues(alpha: 0.15),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: g.progress,
            child: Container(color: c.acidText),
          ),
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.tab,
    required this.selected,
    required this.slot,
    required this.isGuest,
  });

  final ({IconData icon, String label}) tab;
  final bool selected;

  /// Vị trí tab, dùng để biết tab nào mang chấm báo.
  final int slot;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Ô bo tròn nền nhạt sau biểu tượng. Nhạt chứ không đặc: việc báo
            // tab nào đang chọn đã do màu icon và màu chữ đảm nhiệm.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
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
            if (!isGuest) _Badge(slot: slot),
          ],
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

/// Chấm báo trên tab.
///
///   Cơ hội — chấm khi có tin đăng SAU lần xem cuối. Không phải "tin mới nhất
///            trong hệ thống" mà là "tin bạn chưa thấy", hai thứ khác nhau.
///   Hồ sơ  — số tin đã lưu.
///
/// Chỉ hiện khi đã đăng nhập: cả hai con số đều vô nghĩa với khách.
class _Badge extends StatelessWidget {
  const _Badge({required this.slot});
  final int slot;

  @override
  Widget build(BuildContext context) {
    if (slot == 1) {
      return ListenableBuilder(
        listenable: SeenStore.instance,
        builder: (context, _) =>
            _dot(context, SeenStore.instance.newCount, showNumber: false),
      );
    }
    if (slot == 3) {
      return ListenableBuilder(
        listenable: SavedStore.instance,
        builder: (context, _) =>
            _dot(context, SavedStore.instance.count, showNumber: true),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _dot(BuildContext context, int n, {required bool showNumber}) {
    if (n <= 0) return const SizedBox.shrink();
    final c = Np.of(context);
    return Positioned(
      right: 6,
      top: -2,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: showNumber ? 5 : 0),
        constraints: BoxConstraints(minWidth: showNumber ? 16 : 8),
        height: showNumber ? 16 : 8,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.acidText,
          borderRadius: BorderRadius.circular(Np.rPill),
          // Viền cùng màu nền thanh, để chấm tách khỏi biểu tượng bên dưới
          // thay vì dính vào nó.
          border: Border.all(color: c.surface, width: 1.5),
        ),
        child: showNumber
            ? Text(
                n > 99 ? '99+' : '$n',
                style: NpType.meta.copyWith(
                  fontSize: 9.5,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: c.surface,
                ),
              )
            : null,
      ),
    );
  }
}
