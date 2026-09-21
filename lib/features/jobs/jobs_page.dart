import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cơ hội',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: NpColors.emerald,
        backgroundColor: NpColors.inkSoft,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: NpColors.emerald),
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
                      NpSpace.gutter, 4, NpSpace.gutter, 28),
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
        padding: const EdgeInsets.symmetric(horizontal: NpSpace.gutter),
        itemCount: defs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (tab, label, count) = defs[i];
          final active = tab == current;
          return Center(
            child: GestureDetector(
              onTap: () => onChanged(tab),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? NpColors.emerald : Colors.transparent,
                  borderRadius: BorderRadius.circular(NpRadius.pill),
                  border: Border.all(
                    color: active ? NpColors.emerald : NpColors.lineDark,
                  ),
                ),
                child: Text(
                  '$label  $count',
                  style: TextStyle(
                    // Chữ trên nền emerald là ink, không phải trắng — DESIGN.md
                    color: active ? NpColors.ink : NpColors.mutedDark,
                    fontWeight: FontWeight.w700,
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
          Icon(Icons.inbox_outlined, size: 44, color: NpColors.mutedDark),
          SizedBox(height: 14),
          Center(
            child: Text(
              'Chưa có cơ hội nào ở mục này',
              style: TextStyle(color: NpColors.mutedDark),
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
        padding: const EdgeInsets.all(NpSpace.gutter),
        children: [
          const SizedBox(height: 70),
          const Icon(Icons.cloud_off_outlined,
              size: 44, color: NpColors.mutedDark),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NpColors.mutedDark, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Đang gọi: ${AppConfig.apiUrl}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: NpColors.mutedDark, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: NpColors.emerald,
                foregroundColor: NpColors.ink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: const Text('Thử lại',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
}
