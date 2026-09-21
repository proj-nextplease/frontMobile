import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/opportunities_repository.dart';
import '../jobs/opportunity.dart';
import '../jobs/opportunity_detail_page.dart';
import '../jobs/opportunity_labels.dart';
import '../jobs/saved_store.dart';
import '../profile/gamification_store.dart';

/// Trang chủ.
///
/// ─── Vì sao bản trước trông "máy làm" ────────────────────────────────────
/// Mọi khối đều là một thẻ chữ nhật bo góc, viền mờ, cách đều nhau, xếp dọc.
/// Không có gì trội hơn gì, không có nhịp, không có chỗ nào phá khung. Cộng
/// thêm hai ô thống kê đối xứng và vài emoji làm trang trí — đó là công thức
/// của một giao diện dựng vội.
///
/// Bản này đổi ba thứ ở tầng bố cục, không phải tầng màu:
///
///   1. DẢI MÀU TRÀN MÉP ở đầu trang, bo một góc lớn lệch hẳn sang trái. Nó
///      là khối duy nhất trội hẳn lên, nên mắt có chỗ để bắt đầu.
///   2. HAI Ô CHỒNG LÊN mép dải, không nằm gọn bên dưới. Chỗ chồng lấn đó là
///      thứ khiến bố cục đọc ra là "có người sắp đặt".
///   3. BĂNG CHUYỀN NGANG thay cho chồng thẻ dọc. Thẻ dọc khiến trang chủ
///      thành bản sao thu nhỏ của tab Cơ hội; băng chuyền nói rõ "đây là vài
///      cái tiêu biểu, muốn đủ thì sang bên kia".
///
/// Và bỏ hết emoji — thay bằng biểu tượng vẽ tay trong bộ NpIcon.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.isGuest,
    required this.onSignIn,
    required this.onSeeAll,
  });

  final bool isGuest;
  final VoidCallback onSignIn;
  final VoidCallback onSeeAll;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ApiClient();
  late final _repo = OpportunitiesRepository(_api);

  final _scroll = ScrollController();

  /// Dải màu ở đầu trang TỐI, nên khi nó còn che thanh trạng thái thì giờ và
  /// pin phải sáng. Cuộn qua nó rồi thì nền lại sáng và chữ phải tối lại.
  ///
  /// Không có chỗ này thì ở chế độ sáng, giờ và pin gần như vô hình trên dải.
  bool _overBand = true;

  List<Opportunity> _items = const [];
  List<Map<String, dynamic>> _topics = const [];
  int _applications = 0;
  String? _email;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  /// Ngưỡng là chiều cao dải trừ đi phần thanh trạng thái. Đổi sớm hơn một
  /// nhịp để chữ không kịp lẫn vào nền lúc đang chuyển.
  void _onScroll() {
    final over = _scroll.offset < 150;
    if (over != _overBand) setState(() => _overBand = over);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomePage old) {
    super.didUpdateWidget(old);
    // IndexedStack dựng cả bốn tab từ đầu nên initState KHÔNG chạy lại khi
    // người dùng đăng nhập. Không nạp lại ở đây thì trang chủ kẹt ở bản dành
    // cho khách dù đã có phiên.
    if (old.isGuest != widget.isGuest) _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetchAll();
      if (mounted) setState(() => _items = data);
    } on ApiException {
      // Danh sách rỗng đã tự nói lên vấn đề.
    }

    final topics = await _get('/discussions/topics');
    if (mounted && topics is List) {
      setState(() =>
          _topics = topics.whereType<Map<String, dynamic>>().toList());
    }

    if (!widget.isGuest) {
      // Hai lệnh gọi này CHỈ dành cho người đã đăng nhập; gọi khi là khách sẽ
      // nhận 401 và không mang lại gì.
      final me = await _get('/me');
      final apps = await _get('/me/applications');
      if (mounted) {
        setState(() {
          _email = me is Map ? '${me['email'] ?? ''}' : null;
          _applications = apps is List ? apps.length : 0;
        });
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<dynamic> _get(String path) async {
    try {
      return await _api.get(path);
    } on ApiException {
      return null;
    }
  }

  /// Chào theo giờ. Chi tiết nhỏ nhưng là khác biệt giữa "một màn hình" và
  /// "một màn hình biết bạn vừa mở nó lúc nào".
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Sáng rồi';
    if (h < 14) return 'Trưa rồi';
    if (h < 18) return 'Chiều rồi';
    return 'Tối rồi';
  }

  String get _name {
    final e = _email;
    if (widget.isGuest || e == null || e.isEmpty) return 'bạn ơi';
    final at = e.indexOf('@');
    return at > 0 ? e.substring(0, at) : e;
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Mới nhất trước. Tin thiếu createdAt xuống cuối chứ không nhảy lên đầu:
    // thiếu dữ liệu không phải lý do để được ưu tiên.
    final recent = [..._items]..sort((a, b) {
        final x = a.createdAt, y = b.createdAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    final rail = recent.take(6).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Lộn ngược so với các tab khác khi đang ở trên dải: iOS đọc
        // statusBarBrightness (mô tả NỀN), Android đọc statusBarIconBrightness
        // (mô tả ICON).
        statusBarBrightness: _overBand
            ? Brightness.dark
            : (isDark ? Brightness.dark : Brightness.light),
        statusBarIconBrightness: _overBand
            ? Brightness.light
            : (isDark ? Brightness.light : Brightness.dark),
      ),
      child: RefreshIndicator(
      onRefresh: _load,
      color: c.acidText,
      backgroundColor: c.surfaceHi,
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.only(bottom: Np.navInset),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _Band(greeting: _greeting, name: _name, isGuest: widget.isGuest),

          // Kéo lên đè lên mép dải. Đây là chỗ chồng lấn cố ý — thứ khiến bố
          // cục đọc ra là có người sắp đặt, không phải máy xếp hàng.
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
              child: widget.isGuest
                  ? _GuestCta(onSignIn: widget.onSignIn)
                  : _Counters(applications: _applications),
            ),
          ),

          const SizedBox(height: Np.s2),
          _RailHead(
            title: 'Vừa lên sàn',
            action: 'Tất cả',
            onTap: widget.onSeeAll,
          ),
          const SizedBox(height: Np.s4),
          SizedBox(
            height: 186,
            child: _loading && rail.isEmpty
                ? _RailSkeleton()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: Np.gutter),
                    itemCount: rail.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Np.s3),
                    itemBuilder: (_, i) => _RailCard(
                      item: rail[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OpportunityDetailPage(
                            summary: rail[i],
                            isGuest: widget.isGuest,
                            onSignIn: widget.onSignIn,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          if (_topics.isNotEmpty) ...[
            const SizedBox(height: Np.s8),
            const _RailHead(title: 'Sinh viên đang bàn'),
            const SizedBox(height: Np.s4),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
                itemCount: _topics.length,
                separatorBuilder: (_, _) => const SizedBox(width: Np.s2),
                itemBuilder: (_, i) => _TopicChip(topic: _topics[i]),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

/// Dải màu đầu trang, tràn hết bề ngang và chạy lên dưới thanh trạng thái.
class _Band extends StatelessWidget {
  const _Band({
    required this.greeting,
    required this.name,
    required this.isGuest,
  });

  final String greeting;
  final String name;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(Np.gutter, top + Np.s5, Np.gutter, Np.s10),
      decoration: BoxDecoration(
        color: c.band,
        // CHỈ bo góc dưới-trái, và bo rất lớn. Bo đều bốn góc là hình dạng
        // trung tính nhất có thể; lệch một góc làm nó thành một hình có chủ ý.
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(52),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('nextplease',
                  style: NpType.meta.copyWith(
                    color: c.onBand,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  )),
              Text(':',
                  style: NpType.meta.copyWith(
                    color: c.acid,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: Np.s6),
          Text(greeting,
              style: NpType.meta.copyWith(
                  color: c.onBand.withValues(alpha: 0.55))),
          Text(
            name,
            style: NpType.display.copyWith(fontSize: 38, color: c.onBand),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isGuest) ...[
            const SizedBox(height: Np.s5),
            const _LevelStrip(),
          ],
        ],
      ),
    );
  }
}

/// Cấp, vạch EXP và chuỗi ngày, gộp thành MỘT dòng trong dải.
///
/// Gộp chứ không tách thành thẻ riêng: ba con số này cùng nói một chuyện —
/// bạn đang tiến tới đâu — nên tách ra ba ô là làm loãng chính nó.
class _LevelStrip extends StatelessWidget {
  const _LevelStrip();

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return ListenableBuilder(
      listenable: GamificationStore.instance,
      builder: (context, _) {
        final g = GamificationStore.instance;
        return Row(
          children: [
            NpIco(NpIcon.bolt, size: 17, color: c.acid),
            const SizedBox(width: 6),
            Text('Cấp ${g.level}',
                style: NpType.meta.copyWith(
                  color: c.onBand,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(width: Np.s3),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Np.rPill),
                child: Container(
                  height: 5,
                  color: c.onBand.withValues(alpha: 0.18),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: g.progress,
                    child: Container(color: c.acid),
                  ),
                ),
              ),
            ),
            if (g.streak > 0) ...[
              const SizedBox(width: Np.s3),
              NpIco(NpIcon.flame, size: 16, color: c.acid),
              const SizedBox(width: 4),
              Text('${g.streak}',
                  style: NpType.meta.copyWith(
                    color: c.onBand,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ],
        );
      },
    );
  }
}

/// Hai ô đếm, chồng lên mép dải.
class _Counters extends StatelessWidget {
  const _Counters({required this.applications});
  final int applications;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: SavedStore.instance,
              builder: (context, _) => _Counter(
                icon: NpIcon.heartFill,
                value: SavedStore.instance.count,
                label: 'đã lưu',
              ),
            ),
          ),
          const SizedBox(width: Np.s3),
          Expanded(
            child: _Counter(
              icon: NpIcon.send,
              value: applications,
              label: 'đã nộp',
            ),
          ),
        ],
      );
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.icon,
    required this.value,
    required this.label,
  });

  final NpIcon icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(Np.s4, Np.s3, Np.s4, Np.s3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Np.rMd),
        border: Border.all(color: c.line),
        // Ô này NỔI lên trên dải nên cần bóng, khác với mọi thẻ khác trong app.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          NpIco(icon, size: 17, color: c.acidText),
          const SizedBox(width: Np.s2),
          Text('$value',
              style: NpType.h1.copyWith(fontSize: 22, color: c.ink)),
          const SizedBox(width: 5),
          Text(label, style: NpType.meta.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}

class _GuestCta extends StatelessWidget {
  const _GuestCta({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Np.rLg),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Làm được việc gì, có minh chứng việc đó',
              style: NpType.title.copyWith(fontSize: 18, color: c.ink)),
          const SizedBox(height: Np.s2),
          Text('Đăng nhập để lưu tin, nộp đơn và tích EXP.',
              style: NpType.meta.copyWith(color: c.muted)),
          const SizedBox(height: Np.s5),
          AcidButton(label: 'Đăng nhập', onTap: onSignIn),
        ],
      ),
    );
  }
}

class _RailHead extends StatelessWidget {
  const _RailHead({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title,
              style: NpType.h1.copyWith(fontSize: 23, color: c.ink)),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(action!,
                      style: NpType.meta.copyWith(
                        color: c.acidText,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(width: 5),
                  NpIco(NpIcon.arrow, size: 15, color: c.acidText),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Thẻ trong băng chuyền: hẹp, cao cố định, chỉ giữ ba thông tin.
///
/// Cắt bớt so với thẻ ở tab Cơ hội là có chủ ý — đây là bản xem lướt, không
/// phải bản đầy đủ. Giữ nguyên mọi chi tiết thì băng chuyền lại thành danh
/// sách nằm ngang, và trang chủ lại thành bản sao của tab bên cạnh.
class _RailCard extends StatelessWidget {
  const _RailCard({required this.item, required this.onTap});
  final Opportunity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final hasPay = item.compensation != null && item.compensation! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 254,
        padding: const EdgeInsets.all(Np.s4),
        decoration: Np.card(c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.companyName,
                      style: NpType.meta.copyWith(color: c.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (item.isQuest)
                  const MetaChip(label: 'Quest', accent: true),
              ],
            ),
            const SizedBox(height: Np.s3),
            Expanded(
              child: Text(
                item.title,
                style: NpType.title.copyWith(fontSize: 17, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: Np.s3),
            Text(
              item.isQuest
                  ? rewardLine(exp: item.expReward, np: item.npReward)
                  : salaryLabel(compensation: item.compensation, isQuest: false),
              style: NpType.title.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: hasPay || item.isQuest ? c.acidText : c.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(item.location ?? 'Không rõ',
                style: NpType.meta.copyWith(fontSize: 12, color: c.faint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic});
  final Map<String, dynamic> topic;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Np.s4, vertical: Np.s2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Np.rPill),
        border: Border.all(color: c.line),
      ),
      child: Text('${topic['name'] ?? ''}',
          style: NpType.meta.copyWith(
            color: c.ink,
            fontWeight: FontWeight.w500,
          )),
    );
  }
}

class _RailSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
      itemCount: 2,
      separatorBuilder: (_, _) => const SizedBox(width: Np.s3),
      itemBuilder: (_, _) => Container(width: 254, decoration: Np.card(c)),
    );
  }
}
