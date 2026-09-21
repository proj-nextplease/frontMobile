import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import 'opportunities_repository.dart';
import 'opportunity.dart';
import 'opportunity_filter.dart';
import 'opportunity_card.dart';
import 'opportunity_detail_page.dart';
import 'seen_store.dart';

enum OrgTab { all, business, club }

class JobsPage extends StatefulWidget {
  const JobsPage({super.key, this.isGuest = false, this.onSignIn});

  /// Người dùng vào đây qua nút "Xem cơ hội trước đã", chưa đăng nhập.
  ///
  /// Danh sách cơ hội là công khai nên vẫn xem được, nhưng lưu tin và nộp đơn
  /// thì không. Nếu không nói gì thì họ sẽ bấm vào một tin rồi mới phát hiện
  /// mình bị chặn — và lúc đó không có đường nào quay lại màn hình đăng nhập.
  final bool isGuest;

  /// Quay về màn hình đăng nhập. Chỉ có ý nghĩa khi [isGuest].
  final VoidCallback? onSignIn;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  late final OpportunitiesRepository _repo =
      OpportunitiesRepository(ApiClient());

  List<Opportunity> _items = const [];
  String? _error;
  bool _loading = true;
  OrgTab _tab = OrgTab.all;
  OppFilter _filter = const OppFilter();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchAll(force: true);
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
      SeenStore.instance.recount(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Widget _card(Opportunity item) => OpportunityCard(
        item: item,
        isGuest: widget.isGuest,
        onNeedSignIn: widget.onSignIn,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OpportunityDetailPage(
              summary: item,
              isGuest: widget.isGuest,
              onSignIn: widget.onSignIn,
            ),
          ),
        ),
      );

  /// Vị trí chèn ô gợi ý. Đặt sau ba thẻ chứ không phải trên cùng: người dùng
  /// vừa chủ động bấm "xem trước đã", chặn họ ngay lập tức bằng một lời mời
  /// đăng nhập là đi ngược điều họ vừa chọn. Để họ xem vài tin rồi mới mời.
  static const _kPromptAt = 3;

  bool _showPrompt(int count) => widget.isGuest && count > _kPromptAt;

  /// Danh sách sau hàng tab đơn vị, TRƯỚC bộ lọc chi tiết.
  ///
  /// Tách hai bước là có chủ ý: các lựa chọn trong tấm lọc phải dựng từ danh
  /// sách này, không phải từ `_items`. Dựng từ `_items` thì đang ở tab CLB mà
  /// tấm lọc vẫn bày ra những loại cơ hội chỉ doanh nghiệp mới có, bấm vào là
  /// ra rỗng.
  List<Opportunity> get _byOrg => switch (_tab) {
        OrgTab.all => _items,
        OrgTab.business => _items.where((e) => !e.isClub).toList(),
        OrgTab.club => _items.where((e) => e.isClub).toList(),
      };

  List<Opportunity> get _filtered =>
      _byOrg.where(_filter.matches).toList();

  Future<void> _openFilter() async {
    final next = await showOppFilterSheet(
      context,
      source: _byOrg,
      current: _filter,
    );
    if (next != null && mounted) setState(() => _filter = next);
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Nền tối nên chữ thanh trạng thái phải SÁNG. iOS đọc
      // statusBarBrightness (mô tả NỀN), Android đọc statusBarIconBrightness
      // (mô tả ICON) — hai trường ngược nghĩa nhau.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          titleSpacing: Np.gutter,
          toolbarHeight: 74,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SectionLabel('Việc làm & Quest'),
              const SizedBox(height: Np.s2),
              Text('Cơ hội', style: NpType.h1.copyWith(color: c.ink)),
            ],
          ),
          // Không còn nút "Đăng nhập" ở đây: đã có tab Hồ sơ làm chỗ đó, và
          // hai lối vào cùng một việc trên cùng màn hình là thừa. Ô gợi ý xen
          // giữa danh sách vẫn giữ, vì nó xuất hiện đúng lúc người dùng đang
          // xem tin chứ không phải khi họ đi tìm tài khoản.
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          color: c.acid,
          backgroundColor: c.surfaceHi,
          child: _buildBody(c),
        ),
      ),
    );
  }

  Widget _buildBody(NpColors c) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: c.acidText, strokeWidth: 2.4),
      );
    }
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);

    final list = _filtered;
    return Column(
      children: [
        _Tabs(
          current: _tab,
          counts: (
            all: _items.length,
            business: _items.where((e) => !e.isClub).length,
            club: _items.where((e) => e.isClub).length,
          ),
          onChanged: (t) => setState(() => _tab = t),
        ),
        _FilterBar(
          filter: _filter,
          hits: list.length,
          total: _byOrg.length,
          onOpen: _openFilter,
          onClear: () => setState(() => _filter = const OppFilter()),
        ),
        Expanded(
          child: list.isEmpty
              ? (_filter.isEmpty
                  ? const _EmptyView()
                  : _NoMatchView(
                      onClear: () =>
                          setState(() => _filter = const OppFilter())))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Np.gutter, Np.s2, Np.gutter, Np.navInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Chèn thêm một ô gợi ý đăng nhập vào giữa danh sách, nên
                  // số phần tử nhiều hơn số cơ hội đúng một.
                  itemCount: list.length + (_showPrompt(list.length) ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: Np.s3),
                  itemBuilder: (_, i) {
                    if (_showPrompt(list.length)) {
                      if (i == _kPromptAt) {
                        return _SignInPrompt(onTap: widget.onSignIn);
                      }
                      // Sau vị trí chèn thì chỉ số dịch lùi một bậc.
                      if (i > _kPromptAt) {
                        return _card(list[i - 1]);
                      }
                    }
                    return _card(list[i]);
                  },
                ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.current,
    required this.counts,
    required this.onChanged,
  });

  final OrgTab current;
  final ({int all, int business, int club}) counts;
  final ValueChanged<OrgTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final defs = <(OrgTab, String, int)>[
      (OrgTab.all, 'Tất cả', counts.all),
      (OrgTab.business, 'Doanh nghiệp', counts.business),
      (OrgTab.club, 'CLB & Đoàn hội', counts.club),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
        itemCount: defs.length,
        separatorBuilder: (_, _) => const SizedBox(width: Np.s2),
        itemBuilder: (_, i) {
          final (tab, label, count) = defs[i];
          final active = tab == current;
          return Center(
            child: GestureDetector(
              onTap: () => onChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s4, vertical: Np.s2 + 2),
                decoration: BoxDecoration(
                  color: active ? c.acid : Colors.transparent,
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(color: active ? c.acid : c.line),
                ),
                child: Text(
                  '$label  $count',
                  style: NpType.meta.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: active ? c.onAcid : c.muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ô gợi ý đăng nhập, nằm xen giữa danh sách.
///
/// Nói CỤ THỂ đăng nhập để được gì, thay vì chỉ "đăng nhập đi". Người dùng
/// đang xem việc làm; lý do thuyết phục nhất là những việc họ sắp muốn làm
/// với chính những tin này.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: Np.card(c, hi: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Đang xem với tư cách khách'),
          const SizedBox(height: Np.s3),
          Text(
            'Đăng nhập để lưu tin và nộp đơn',
            style: NpType.title.copyWith(fontSize: 18, color: c.ink),
          ),
          const SizedBox(height: Np.s2),
          Text(
            'Hồ sơ năng lực của bạn cũng nằm ở đây — mỗi việc hoàn thành là một '
            'minh chứng được xác thực.',
            style: NpType.meta.copyWith(color: c.muted),
          ),
          const SizedBox(height: Np.s5),
          AcidButton(
            label: 'Đăng nhập',
            onTap: onTap ?? () {},
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        Icon(Icons.inbox_rounded, size: 40, color: c.faint),
        const SizedBox(height: Np.s4),
        Center(
          child: Text('Chưa có cơ hội nào ở mục này',
              style: NpType.meta.copyWith(color: c.muted)),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Np.gutter),
      children: [
        const SizedBox(height: 70),
        Icon(Icons.cloud_off_rounded, size: 40, color: c.faint),
        const SizedBox(height: Np.s4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: NpType.body.copyWith(color: c.ink),
        ),
        const SizedBox(height: Np.s2),
        Text(
          'Đang gọi: ${AppConfig.apiUrl}',
          textAlign: TextAlign.center,
          style: NpType.meta.copyWith(fontSize: 12, color: c.faint),
        ),
        const SizedBox(height: Np.s5),
        Center(
          child: AcidButton(label: 'Thử lại', onTap: onRetry, expand: false),
        ),
      ],
    );
  }
}

/// Hàng nút lọc. Một nút duy nhất, cộng một lối thoát khi đang có bộ lọc bật.
///
/// Con số "x/y tin" nằm ở đây chứ không phải trong tấm lọc, vì đây mới là lúc
/// người dùng nhìn vào danh sách và cần biết mình đang không thấy hết.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.hits,
    required this.total,
    required this.onOpen,
    required this.onClear,
  });

  final OppFilter filter;
  final int hits;
  final int total;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final on = !filter.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Np.gutter, 0, Np.gutter, Np.s3),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Np.s4, vertical: Np.s2 + 2),
              decoration: BoxDecoration(
                color: on ? c.acid.withValues(alpha: 0.16) : c.surface,
                borderRadius: BorderRadius.circular(Np.rPill),
                border: Border.all(
                    color: on ? c.acid.withValues(alpha: 0.55) : c.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NpIco(NpIcon.search,
                      size: 15, color: on ? c.acidText : c.muted),
                  const SizedBox(width: Np.s2),
                  Text(
                    on ? 'Lọc · ${filter.activeCount}' : 'Lọc',
                    style: NpType.meta.copyWith(
                      fontSize: 13.5,
                      color: on ? c.acidText : c.ink,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Np.s3),
          if (on)
            Expanded(
              child: Text('$hits / $total tin',
                  style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted)),
            )
          else
            const Spacer(),
          if (on)
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Text('Xoá lọc',
                  style: NpType.meta.copyWith(
                    fontSize: 13,
                    color: c.danger,
                    fontWeight: FontWeight.w600,
                  )),
            ),
        ],
      ),
    );
  }
}

/// Rỗng vì bộ lọc, không phải vì hết tin. Hai câu khác nhau và một lối ra —
/// dùng chung `_EmptyView` ở đây sẽ nói với người dùng rằng sàn không có việc,
/// trong khi thật ra họ vừa chọn quá tay.
class _NoMatchView extends StatelessWidget {
  const _NoMatchView({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Np.s10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NpIco(NpIcon.search, size: 26, color: c.faint),
            const SizedBox(height: Np.s4),
            Text('Không có tin nào khớp bộ lọc',
                style: NpType.title.copyWith(fontSize: 17, color: c.ink),
                textAlign: TextAlign.center),
            const SizedBox(height: Np.s2),
            Text('Thử bỏ bớt một vài lựa chọn.',
                style: NpType.meta.copyWith(color: c.muted),
                textAlign: TextAlign.center),
            const SizedBox(height: Np.s5),
            AcidButton(label: 'Xoá bộ lọc', onTap: onClear, expand: false),
          ],
        ),
      ),
    );
  }
}
