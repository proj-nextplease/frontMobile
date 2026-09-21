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
      // Nền sáng nên phải ép chữ thanh trạng thái sang tối, nếu không giờ và
      // pin vẽ màu trắng và gần như vô hình.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,    // iOS mô tả NỀN
        statusBarIconBrightness: Brightness.dark, // Android mô tả ICON
      ),
      child: Scaffold(
        backgroundColor: Paper.bg,
        appBar: AppBar(
          titleSpacing: NpSpace.gutter,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: Paper.card(fill: Paper.lime, radius: 10, dx: 3, dy: 3),
                child: const Text(
                  'Cơ hội',
                  style: TextStyle(
                    color: Paper.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          color: Paper.ink,
          backgroundColor: Paper.lime,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Paper.ink, strokeWidth: 3),
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? Paper.lime : Paper.bg,
                  borderRadius: BorderRadius.circular(NpRadius.pill),
                  border: Border.all(color: Paper.ink, width: Paper.border),
                  // Bóng cứng CHỈ cho chip đang chọn — đây là thứ đơn lẻ trên
                  // màn hình, khác với thẻ trong danh sách.
                  boxShadow: active ? Paper.hardShadow(dx: 3, dy: 3) : null,
                ),
                child: Text(
                  '$label  $count',
                  style: TextStyle(
                    color: Paper.ink,
                    fontWeight: FontWeight.w800,
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
          Icon(Icons.inbox_outlined, size: 44, color: Paper.ink),
          SizedBox(height: 14),
          Center(
            child: Text(
              'Chưa có cơ hội nào ở mục này',
              style: TextStyle(color: Paper.ink, fontWeight: FontWeight.w600),
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
          const Icon(Icons.cloud_off_outlined, size: 44, color: Paper.ink),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Paper.ink, height: 1.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Đang gọi: ${AppConfig.apiUrl}',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Paper.ink.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: Paper.lime,
                foregroundColor: Paper.ink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: StadiumBorder(
                  side: BorderSide(color: Paper.ink, width: Paper.border),
                ),
              ),
              child: const Text('Thử lại',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
}
