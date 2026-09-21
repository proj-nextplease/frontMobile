import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import 'opportunities_repository.dart';
import 'opportunity.dart';
import 'opportunity_card.dart';

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
      final data = await _repo.fetchAll();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Vị trí chèn ô gợi ý. Đặt sau ba thẻ chứ không phải trên cùng: người dùng
  /// vừa chủ động bấm "xem trước đã", chặn họ ngay lập tức bằng một lời mời
  /// đăng nhập là đi ngược điều họ vừa chọn. Để họ xem vài tin rồi mới mời.
  static const _kPromptAt = 3;

  bool _showPrompt(int count) => widget.isGuest && count > _kPromptAt;

  List<Opportunity> get _filtered => switch (_tab) {
        OrgTab.all => _items,
        OrgTab.business => _items.where((e) => !e.isClub).toList(),
        OrgTab.club => _items.where((e) => e.isClub).toList(),
      };

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
          actions: [
            // Đường quay lại, luôn thấy được. Không dùng mũi tên back của hệ
            // thống: ở đây không có ngăn xếp điều hướng để quay về, và nhãn
            // chữ nói rõ bấm vào sẽ được gì.
            if (widget.isGuest)
              Padding(
                padding: const EdgeInsets.only(right: Np.gutter),
                child: GestureDetector(
                  onTap: widget.onSignIn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Np.s4, vertical: Np.s2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Np.rPill),
                      border: Border.all(color: c.line),
                    ),
                    child: Text(
                      'Đăng nhập',
                      style: NpType.meta.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
        Expanded(
          child: list.isEmpty
              ? const _EmptyView()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Np.gutter, Np.s2, Np.gutter, Np.s10),
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
                        return OpportunityCard(item: list[i - 1]);
                      }
                    }
                    return OpportunityCard(item: list[i]);
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
