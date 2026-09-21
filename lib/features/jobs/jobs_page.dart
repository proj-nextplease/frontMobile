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
  const JobsPage({super.key});
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

  List<Opportunity> get _filtered => switch (_tab) {
        OrgTab.all => _items,
        OrgTab.business => _items.where((e) => !e.isClub).toList(),
        OrgTab.club => _items.where((e) => e.isClub).toList(),
      };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Nền tối nên chữ thanh trạng thái phải SÁNG. iOS đọc
      // statusBarBrightness (mô tả NỀN), Android đọc statusBarIconBrightness
      // (mô tả ICON) — hai trường ngược nghĩa nhau.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Np.bg,
        appBar: AppBar(
          titleSpacing: Np.gutter,
          toolbarHeight: 62,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Cơ hội',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 27,
                        letterSpacing: -0.9,
                      )),
              Text('${_items.length} vị trí đang mở',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          color: Np.violet,
          backgroundColor: Np.surface,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Np.violet, strokeWidth: 3),
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
                      Np.gutter, 4, Np.gutter, 28),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => OpportunityCard(item: list[i]),
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
    final defs = <(OrgTab, String, int)>[
      (OrgTab.all, 'Tất cả', counts.all),
      (OrgTab.business, 'Doanh nghiệp', counts.business),
      (OrgTab.club, 'CLB & Đoàn hội', counts.club),
    ];

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
        itemCount: defs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (tab, label, count) = defs[i];
          final active = tab == current;
          return Center(
            child: GestureDetector(
              onTap: () => onChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  // Chip đang chọn mang gradient thương hiệu; chip nghỉ là thẻ
                  // trắng. Không viền ở cả hai trạng thái.
                  gradient: active ? Np.brand : null,
                  color: active ? null : Np.surface,
                  border: active ? null : Border.all(color: Np.line),
                  borderRadius: BorderRadius.circular(Np.rPill),
                  boxShadow: active ? Np.glow : null,
                ),
                child: Text(
                  '$label  $count',
                  style: TextStyle(
                    color: active ? Colors.white : Np.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.6,
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 90),
          Icon(Icons.inbox_rounded, size: 44, color: Np.muted),
          SizedBox(height: 14),
          Center(
            child: Text(
              'Chưa có cơ hội nào ở mục này',
              style: TextStyle(color: Np.muted, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Np.gutter),
        children: [
          const SizedBox(height: 70),
          const Icon(Icons.cloud_off_rounded, size: 44, color: Np.muted),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Np.ink, height: 1.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Đang gọi: ${AppConfig.apiUrl}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Np.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 170,
              child: GradientButton(label: 'Thử lại', onTap: onRetry),
            ),
          ),
        ],
      );
}
