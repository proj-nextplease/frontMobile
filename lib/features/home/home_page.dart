import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/opportunities_repository.dart';
import '../jobs/opportunity.dart';
import '../jobs/opportunity_detail_page.dart';
import '../jobs/opportunity_labels.dart';
import '../jobs/saved_store.dart';
import '../profile/application_item.dart';
import '../profile/edit_profile_page.dart';
import '../profile/gamification_store.dart';
import '../profile/me_store.dart';
import '../profile/notification_bell.dart';
import '../profile/quest_board.dart';
import '../profile/notifications_store.dart';

/// Trang chủ.
///
/// ─── Vì sao bản trước bị bỏ ──────────────────────────────────────────────
/// Nó có ba mục — "Vừa lên sàn", "Sắp hết hạn", và khối kết thúc — nhưng cả
/// ba đều là CÙNG một danh sách cơ hội, chỉ xếp khác nhau. Cuộn hết trang
/// không biết thêm điều gì. Tệ hơn, tab Cơ hội đã làm đúng việc đó đầy đủ
/// hơn, nên trang chủ chỉ là một bản sao kém hơn của tab bên cạnh.
/// Thứ to nhất màn hình lại là tên cắt từ email của chính người đang nhìn —
/// một thông tin họ đã biết, chiếm một phần tư màn hình đầu.
///
/// ─── Bản này ─────────────────────────────────────────────────────────────
/// Trang chủ trả lời "HÔM NAY TÔI NÊN LÀM GÌ", tab Cơ hội trả lời "thị
/// trường đang có gì". Hai câu khác nhau nên hai màn hình không còn giẫm
/// chân nhau.
///
///   1. MỘT thẻ lớn duy nhất ở trên: cơ hội hợp nhất với hồ sơ người dùng,
///      kèm lý do vì sao nó được chọn. Không phải sáu thẻ ngang nhau.
///   2. MỘT lời nhắc duy nhất, chọn theo mức cấp bách thực tế (xem
///      `_nudge`) — không phải bảng thống kê toàn số 0.
///   3. Nội dung thật ở phần cộng đồng: tiêu đề bài viết, không phải chip
///      chủ đề rỗng.
///
/// Nền sáng liền mạch, không còn dải tối — dải đó buộc mọi màu thương hiệu
/// phải tồn tại ở hai phiên bản, và đó chính là nguồn gốc vụ hai sắc xanh.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.isGuest,
    required this.onSignIn,
    required this.onSeeAll,
    required this.onOpenDiscussions,
    required this.onOpenProfile,
  });

  final bool isGuest;
  final VoidCallback onSignIn;
  final VoidCallback onSeeAll;
  final VoidCallback onOpenDiscussions;
  final VoidCallback onOpenProfile;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ApiClient();
  late final _repo = OpportunitiesRepository(_api);
  final _me = MeStore.instance;

  List<Opportunity> _items = const [];

  /// Lỗi của lần nạp gần nhất. Giữ riêng để phân biệt "chưa có cơ hội nào"
  /// với "không tải được".
  String? _loadError;
  List<Map<String, dynamic>> _posts = const [];
  List<Map<String, dynamic>> _topics = const [];
  List<Map<String, dynamic>> _apps = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _me.addListener(_onMe);
    GamificationStore.instance.addListener(_onMe);
    NotificationsStore.instance.addListener(_onMe);
    SavedStore.instance.addListener(_onMe);
    _load();
  }

  void _onMe() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _me.removeListener(_onMe);
    GamificationStore.instance.removeListener(_onMe);
    NotificationsStore.instance.removeListener(_onMe);
    SavedStore.instance.removeListener(_onMe);
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
      if (mounted) {
        setState(() {
          _items = data;
          _loadError = null;
        });
      }
    } on ApiException catch (e) {
      // Chú thích cũ ở đây ghi "danh sách rỗng đã tự nói lên vấn đề" — đó là
      // một giả định SAI. Danh sách rỗng nói "không có cơ hội nào đang mở",
      // và đó là điều app khẳng định với người dùng khi thật ra chỉ là mạng
      // hỏng. Cùng loại lỗi đã sửa hai lần bên web.
      if (mounted) setState(() => _loadError = e.message);
    }

    final posts = await _get('/discussions/posts');
    if (mounted && posts is List) {
      setState(() =>
          _posts = posts.whereType<Map<String, dynamic>>().take(3).toList());
    }

    // Chủ đề nạp riêng vì nó CÓ dữ liệu ngay cả khi chưa ai đăng bài — và đó
    // chính là trường hợp cần tới: mục cộng đồng rỗng thì mời người dùng mở
    // bài đầu tiên, thay vì biến mất và để lại một khoảng trắng.
    final topics = await _get('/discussions/topics');
    if (mounted && topics is List) {
      setState(() =>
          _topics = topics.whereType<Map<String, dynamic>>().toList());
    }

    if (!widget.isGuest) {
      // Chỉ dành cho người đã đăng nhập; gọi khi là khách sẽ nhận 401.
      await _me.hydrate();
      final apps = await _get('/me/applications');
      if (mounted && apps is List) {
        setState(() => _apps = apps.whereType<Map<String, dynamic>>().toList());
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
    if (h < 11) return 'Chào buổi sáng';
    if (h < 14) return 'Chào buổi trưa';
    if (h < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  /// Chỉ lấy tên gọi, không lấy cả họ — dòng chào dài quá thì nó thành một
  /// câu để đọc chứ không còn là lời chào.
  String? get _firstName {
    final n = _me.name?.trim();
    if (n == null || n.isEmpty) return null;
    final parts = n.split(RegExp(r'\s+'));
    return parts.last;
  }

  // ── Xếp hạng cơ hội ────────────────────────────────────────────────────

  /// Số kỹ năng của tin trùng với kỹ năng trong hồ sơ.
  int _matchCount(Opportunity o) {
    if (_me.skills.isEmpty || o.skills.isEmpty) return 0;
    return o.skills
        .where((s) => _me.skills.contains(s.trim().toLowerCase()))
        .length;
  }

  /// Danh sách cơ hội đã sắp theo mức phù hợp.
  ///
  /// Thứ tự ưu tiên: khớp kỹ năng → hạn gần → mới đăng. Tin đã quá hạn và tin
  /// vượt quá điểm uy tín hiện tại bị loại hẳn, vì gợi ý một việc người dùng
  /// không nộp được là tệ hơn không gợi ý gì.
  List<Opportunity> get _ranked {
    final now = DateTime.now();
    final list = _items.where((o) {
      final d = o.deadlineAt ?? o.endsAt;
      if (d != null && d.isBefore(now)) return false;
      if (_me.loaded && o.minReqRs > _me.reputationScore) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      final m = _matchCount(b).compareTo(_matchCount(a));
      if (m != 0) return m;

      final da = a.deadlineAt ?? a.endsAt;
      final db = b.deadlineAt ?? b.endsAt;
      if (da != null && db != null) return da.compareTo(db);
      if (da != null) return -1;
      if (db != null) return 1;

      final ca = a.createdAt, cb = b.createdAt;
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;
      return cb.compareTo(ca);
    });
    return list;
  }

  /// Câu giải thích vì sao tin này được đưa lên đầu.
  ///
  /// Một gợi ý không nói lý do thì không phải gợi ý, nó là quảng cáo. Thứ tự
  /// các nhánh bám đúng thứ tự xếp hạng ở `_ranked` để lời giải thích luôn
  /// khớp với lý do thật.
  String _reason(Opportunity o) {
    final m = _matchCount(o);
    if (m > 0) {
      return 'Khớp $m/${o.skills.length} kỹ năng trong hồ sơ của bạn';
    }
    final left = daysLeft(o.deadlineAt ?? o.endsAt);
    if (left != null && left <= 14) {
      return left == 0 ? 'Hạn nộp là hôm nay' : 'Chỉ còn $left ngày để nộp';
    }
    if (o.minReqRs == 0) return 'Không yêu cầu điểm uy tín — nộp được ngay';
    return 'Vừa mở, còn nhận hồ sơ';
  }

  // ── Lời nhắc ───────────────────────────────────────────────────────────

  /// Số đơn chưa có kết luận.
  ///
  /// Bản trước so với chuỗi 'PENDING' — trạng thái đó KHÔNG tồn tại. Ràng buộc
  /// ck_applications_status (migration V19) chỉ cho phép SUBMITTED, VIEWED,
  /// SHORTLISTED, ACCEPTED, REJECTED, WITHDRAWN, COMPLETED. Nên con số luôn
  /// bằng 0 và lời nhắc "N đơn đang chờ" không bao giờ hiện ra.
  int get _pending => _apps
      .where((a) => kOpenStatuses.contains('${a['status']}'.toUpperCase()))
      .length;

  /// Một lời nhắc duy nhất, chọn theo việc gì đang chặn người dùng nhiều nhất.
  ///
  /// Cố ý trả về MỘT chứ không phải danh sách: năm lời nhắc cùng lúc thì
  /// không lời nào được đọc, và nó biến trang chủ thành bảng công việc tồn.
  _Nudge? get _nudge {
    if (widget.isGuest) {
      return _Nudge(
        icon: NpIcon.person,
        text: 'Đăng nhập để lưu tin và nộp hồ sơ',
        action: 'Đăng nhập',
        onTap: widget.onSignIn,
      );
    }
    if (!_me.loaded) return null;

    // Thiếu kỹ năng là nghẽn lớn nhất: không có nó thì phép khớp bên trên
    // không chạy, và người dùng chỉ nhận được tin xếp theo hạn nộp.
    if (_me.skills.isEmpty) {
      return _Nudge(
        icon: NpIcon.bolt,
        text: 'Thêm kỹ năng vào hồ sơ để được gợi ý đúng việc hơn',
        action: 'Cập nhật',
        // Mở THẲNG màn sửa, không phải tab Hồ sơ. Lời nhắc nói rõ việc cần
        // làm thì nó phải dẫn tới đúng chỗ làm việc đó, không bắt người dùng
        // tự dò thêm hai lớp nữa.
        onTap: _openEdit,
      );
    }
    if (_pending > 0) {
      return _Nudge(
        icon: NpIcon.send,
        text: '$_pending đơn đang chờ nhà tuyển dụng phản hồi',
        action: 'Xem',
        onTap: widget.onOpenProfile,
      );
    }
    final saved = SavedStore.instance.count;
    if (saved > 0 && _apps.isEmpty) {
      return _Nudge(
        icon: NpIcon.heartFill,
        text: 'Bạn đã lưu $saved tin nhưng chưa nộp đơn nào',
        action: 'Xem lại',
        onTap: widget.onOpenProfile,
      );
    }
    final missing = _me.missing;
    if (missing.isNotEmpty) {
      return _Nudge(
        icon: NpIcon.person,
        text: 'Hồ sơ còn thiếu ${missing.first}',
        action: 'Bổ sung',
        onTap: _openEdit,
      );
    }
    return null;
  }

  // ── Dựng giao diện ─────────────────────────────────────────────────────

  void _openEdit() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EditProfilePage()),
      );

  void _open(Opportunity o) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OpportunityDetailPage(
            summary: o,
            isGuest: widget.isGuest,
            onSignIn: widget.onSignIn,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ranked = _ranked;
    final top = ranked.isEmpty ? null : ranked.first;
    final rest = ranked.skip(1).take(3).toList();
    final nudge = _nudge;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Nền sáng liền mạch từ trên xuống nên thanh trạng thái không còn phải
      // đổi theo độ cuộn — bỏ hẳn được cả ScrollController lẫn ngưỡng đoán
      // chiều cao dải mà bản trước phải nuôi.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: RefreshIndicator(
        onRefresh: _load,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.only(bottom: Np.navInset),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: Np.s4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
                child: _Greeting(
                  greeting: _greeting,
                  name: _firstName,
                  rs: _me.loaded ? _me.reputationScore : null,
                  showBell: !widget.isGuest,
                ),
              ),

              if (nudge != null) ...[
                const SizedBox(height: Np.s5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
                  child: _NudgeBar(nudge: nudge),
                ),
              ],

              // Nhiệm vụ đứng TRƯỚC gợi ý cơ hội: nó là việc làm xong được
              // ngay hôm nay và có thưởng, còn gợi ý là việc cân nhắc lâu hơn.
              if (!widget.isGuest &&
                  GamificationStore.instance.daily.isNotEmpty) ...[
                const SizedBox(height: Np.s8),
                // "Nhiệm vụ" trơn, KHÔNG phải "Nhiệm vụ hôm nay": danh sách
                // trộn cả nhiệm vụ ngày lẫn tuần, nên chữ "hôm nay" nói sai
                // với hai phần ba số dòng. Phạm vi ghi trên từng dòng.
                const _Head(title: 'Nhiệm vụ'),
                const SizedBox(height: Np.s4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
                  child: QuestBoard(store: GamificationStore.instance),
                ),
              ],

              const SizedBox(height: Np.s8),
              const _Head(title: 'Nên xem hôm nay'),
              const SizedBox(height: Np.s4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
                child: top == null
                    ? _EmptyToday(
                        loading: _loading,
                        error: _loadError,
                        onRetry: _load,
                      )
                    : _TodayCard(
                        item: top,
                        reason: _reason(top),
                        onTap: () => _open(top),
                      ),
              ),

              if (rest.isNotEmpty) ...[
                const SizedBox(height: Np.s8),
                _Head(
                  // "Hợp với bạn" chỉ được dùng khi THẬT SỰ có tin khớp kỹ
                  // năng. Có hồ sơ mà không tin nào khớp thì đây chỉ là danh
                  // sách cơ hội khác, và gọi nó là "hợp với bạn" là nói dối
                  // người dùng ngay ở dòng tiêu đề.
                  title: rest.any((o) => _matchCount(o) > 0)
                      ? 'Hợp với bạn'
                      : 'Cơ hội khác đang mở',
                  action: 'Tất cả',
                  onTap: widget.onSeeAll,
                ),
                const SizedBox(height: Np.s4),
                for (final o in rest) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
                    child: _CompactRow(
                      item: o,
                      match: _matchCount(o),
                      onTap: () => _open(o),
                    ),
                  ),
                  const SizedBox(height: Np.s2),
                ],
              ],

              if (_posts.isNotEmpty || _topics.isNotEmpty) ...[
                const SizedBox(height: Np.s8),
                _Head(
                  title: 'Sinh viên đang bàn',
                  action: 'Vào thảo luận',
                  onTap: widget.onOpenDiscussions,
                ),
                const SizedBox(height: Np.s4),
                if (_posts.isNotEmpty)
                  for (final p in _posts) ...[
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Np.gutter),
                      child: _PostRow(
                        post: p,
                        onTap: widget.onOpenDiscussions,
                      ),
                    ),
                    const SizedBox(height: Np.s2),
                  ]
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
                    child: _StartDiscussion(
                      topics: _topics,
                      onTap: widget.onOpenDiscussions,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lời nhắc đã chọn xong — gói lại thành dữ liệu để phần dựng giao diện không
/// phải chứa chuỗi if/else của phần quyết định.
class _Nudge {
  const _Nudge({
    required this.icon,
    required this.text,
    required this.action,
    required this.onTap,
  });
  final NpIcon icon;
  final String text;
  final String action;
  final VoidCallback onTap;
}

/// Dòng chào. Cỡ chữ vừa phải — người dùng đã biết tên mình, nó không cần to
/// bằng nửa màn hình như bản trước.
class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.greeting,
    required this.name,
    required this.rs,
    required this.showBell,
  });
  final String greeting;
  final String? name;
  final int? rs;
  final bool showBell;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('nextplease',
                  style: NpType.label.copyWith(color: c.muted)),
              const SizedBox(height: Np.s1),
              Text(
                name == null ? greeting : '$greeting, $name',
                style: NpType.h1.copyWith(color: c.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (rs != null) ...[
          const SizedBox(width: Np.s3),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Np.s3, vertical: Np.s1 + 2),
            decoration: BoxDecoration(
              color: c.acid.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Np.rPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NpIco(NpIcon.bolt, size: 14, color: c.acidText),
                const SizedBox(width: Np.s1 + 2),
                Text('$rs',
                    style: NpType.meta.copyWith(
                      color: c.acidText,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ],
        if (showBell) ...[
          const SizedBox(width: Np.s1),
          const NotificationBell(),
        ],
      ],
    );
  }
}

/// Thanh nhắc việc. Nền nhạt chứ không viền — nó phải đọc ra là một ghi chú
/// chứ không phải thêm một thẻ nội dung nữa.
class _NudgeBar extends StatelessWidget {
  const _NudgeBar({required this.nudge});
  final _Nudge nudge;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: nudge.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s3 + 2),
        decoration: BoxDecoration(
          color: c.surfaceHi,
          borderRadius: BorderRadius.circular(Np.rMd),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            NpIco(nudge.icon, size: 18, color: c.muted),
            const SizedBox(width: Np.s3),
            Expanded(
              child: Text(nudge.text,
                  style: NpType.meta.copyWith(color: c.ink, fontSize: 13.5),
                  maxLines: 2),
            ),
            const SizedBox(width: Np.s2),
            Text(nudge.action,
                style: NpType.meta.copyWith(
                  color: c.acidText,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}

/// Tiêu đề mục. Không có gạch trang trí, không có emoji — chỉ chữ và, nếu có,
/// một lối đi tiếp.
class _Head extends StatelessWidget {
  const _Head({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: NpType.h1.copyWith(color: c.ink)),
          ),
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
                  const SizedBox(width: Np.s1),
                  NpIco(NpIcon.arrow, size: 15, color: c.acidText),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Thẻ gợi ý chính — khối lớn nhất và là khối DUY NHẤT có nút.
///
/// Dòng lý do đứng TRÊN tiêu đề chứ không phải dưới: người dùng cần biết vì
/// sao mình đang nhìn tin này trước khi quyết định có đọc tiếp không.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.item,
    required this.reason,
    required this.onTap,
  });
  final Opportunity item;
  final String reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final left = daysLeft(item.deadlineAt ?? item.endsAt);
    final pay = item.isQuest
        ? rewardLine(exp: item.expReward, np: item.npReward)
        : salaryLabel(compensation: item.compensation, isQuest: false);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Np.s5),
        decoration: Np.card(c, radius: Np.rLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NpIco(NpIcon.bolt, size: 15, color: c.acidText),
                const SizedBox(width: Np.s2),
                Expanded(
                  child: Text(reason,
                      style: NpType.meta.copyWith(
                        color: c.acidText,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: Np.s4),
            Text(item.title,
                style: NpType.title.copyWith(fontSize: 20, color: c.ink),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: Np.s2),
            Text(item.companyName,
                style: NpType.meta.copyWith(color: c.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),

            const SizedBox(height: Np.s4),
            Wrap(
              spacing: Np.s2,
              runSpacing: Np.s2,
              children: [
                if (pay.isNotEmpty) MetaChip(label: pay),
                if (item.location != null && item.location!.isNotEmpty)
                  MetaChip(label: item.location!),
                if (item.isRemote) const MetaChip(label: 'Remote'),
                if (left != null && left <= 14)
                  MetaChip(label: left == 0 ? 'Hạn hôm nay' : 'Còn $left ngày'),
              ],
            ),

            const SizedBox(height: Np.s5),
            AcidButton(label: 'Xem chi tiết', onTap: onTap),
          ],
        ),
      ),
    );
  }
}

/// Dòng cơ hội rút gọn. Cố tình KHÔNG dùng lại thẻ của tab Cơ hội: thẻ đầy đủ
/// ở đây sẽ làm trang chủ lại thành bản sao của tab bên cạnh.
class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.item,
    required this.match,
    required this.onTap,
  });
  final Opportunity item;
  final int match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final pay = item.isQuest
        ? rewardLine(exp: item.expReward, np: item.npReward)
        : salaryLabel(compensation: item.compensation, isQuest: false);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s3 + 2),
        decoration: Np.card(c, radius: Np.rMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: NpType.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    // Ghép công ty và lương vào MỘT dòng phụ. Tách hai dòng
                    // thì mỗi mục cao thêm 18px và ba mục là gần một phần tư
                    // màn hình cho thông tin hạng hai.
                    pay.isEmpty
                        ? item.companyName
                        : '${item.companyName} · $pay',
                    style: NpType.meta.copyWith(fontSize: 12, color: c.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (match > 0) ...[
              const SizedBox(width: Np.s3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s2 + 2, vertical: 3),
                decoration: BoxDecoration(
                  color: c.acid.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Np.rPill),
                ),
                child: Text('khớp $match',
                    style: NpType.meta.copyWith(
                      fontSize: 11.5,
                      color: c.acidText,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bài thảo luận thật. Bản trước chỉ hiện chip tên chủ đề — một cái nhãn
/// không nói gì và không ai bấm.
class _PostRow extends StatelessWidget {
  const _PostRow({required this.post, required this.onTap});
  final Map<String, dynamic> post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    // discussion_posts KHÔNG có cột tiêu đề (xem V47__discussion_forum.sql):
    // chỉ có `content`. Bản trước đọc post['title'] nên mọi bài đều rơi vào
    // nhánh dự phòng và hiện ra chữ "Bài viết". Dòng đầu của content chính là
    // thứ người đăng viết như tiêu đề, nên lấy đúng dòng đó.
    final content = '${post['content'] ?? ''}'.trim();
    final headline = content.split('\n').first.trim();
    final topic = '${post['topicName'] ?? ''}'.trim();

    // `comments` trong payload là DANH SÁCH bình luận xem trước, không phải số
    // đếm — số đếm nằm ở `commentsCount`. Đọc nhầm thì điều kiện `is num` luôn
    // sai và con số không bao giờ hiện.
    final comments = post['commentsCount'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s3 + 2),
        decoration: Np.card(c, radius: Np.rMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline.isEmpty ? 'Bài viết' : headline,
                      style: NpType.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (topic.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(topic,
                        style:
                            NpType.meta.copyWith(fontSize: 12, color: c.muted)),
                  ],
                ],
              ),
            ),
            if (comments is num && comments > 0) ...[
              const SizedBox(width: Np.s3),
              NpIco(NpIcon.chat, size: 15, color: c.muted),
              const SizedBox(width: Np.s1 + 2),
              Text('$comments',
                  style: NpType.meta.copyWith(fontSize: 12, color: c.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chưa có gì để gợi ý. Hai trạng thái khác nhau — đang tải và thật sự rỗng —
/// nói hai câu khác nhau, vì gộp lại thì lúc mạng chậm người dùng tưởng app
/// trống không.
class _EmptyToday extends StatelessWidget {
  const _EmptyToday({
    required this.loading,
    this.error,
    this.onRetry,
  });
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: Np.s5, vertical: Np.s8),
      decoration: Np.card(c, radius: Np.rLg),
      child: Column(
        children: [
          NpIco(
              error != null
                  ? NpIcon.close
                  : loading
                      ? NpIcon.bolt
                      : NpIcon.search,
              size: 24,
              color: error != null ? c.danger : c.faint),
          const SizedBox(height: Np.s3),
          Text(
            error != null
                ? 'Không tải được cơ hội'
                : loading
                    ? 'Đang tìm việc hợp với bạn…'
                    : 'Chưa có cơ hội nào đang mở',
            style: NpType.meta.copyWith(color: c.muted),
            textAlign: TextAlign.center,
          ),
          if (error != null && onRetry != null) ...[
            const SizedBox(height: Np.s3),
            GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(Np.s2),
                child: Text('Thử lại',
                    style: NpType.button
                        .copyWith(fontSize: 15, color: c.acidText)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chưa ai đăng bài. Nói thẳng ra như vậy và mời người dùng mở bài đầu tiên.
///
/// Cách xử lý khác — giấu hẳn mục này đi — là cách bản trước làm, và nó để lại
/// một khoảng trắng ở cuối trang mà không giải thích gì. Trạng thái rỗng là
/// một trạng thái thật, nó đáng được thiết kế chứ không đáng bị ẩn.
class _StartDiscussion extends StatelessWidget {
  const _StartDiscussion({required this.topics, required this.onTap});
  final List<Map<String, dynamic>> topics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final names = topics
        .map((t) => '${t['name'] ?? ''}'.trim())
        .where((n) => n.isNotEmpty)
        .take(3)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Np.s5),
        decoration: Np.card(c, radius: Np.rLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NpIco(NpIcon.chat, size: 18, color: c.acidText),
                const SizedBox(width: Np.s2 + 2),
                Expanded(
                  child: Text('Chưa có bài nào — bạn mở đầu nhé?',
                      style: NpType.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
            if (names.isNotEmpty) ...[
              const SizedBox(height: Np.s3),
              Text('Đang có ${topics.length} chủ đề: ${names.join(' · ')}',
                  style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

