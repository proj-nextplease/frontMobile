import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/opportunities_repository.dart';
import '../jobs/opportunity.dart';
import '../jobs/opportunity_card.dart';
import '../jobs/opportunity_detail_page.dart';

/// Trang chủ — cửa vào, không phải một danh sách thứ hai.
///
/// Nguyên tắc: trang này KHÔNG lặp lại tab Cơ hội. Nó chỉ trả lời ba câu mà
/// người vừa mở app muốn biết ngay — hiện có bao nhiêu cơ hội, cái nào mới
/// nhất, và tôi nên bấm vào đâu. Ai muốn xem đầy đủ thì sang tab Cơ hội, và
/// nút "Xem tất cả" đưa họ sang đúng đó.
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
  late final _repo = OpportunitiesRepository(ApiClient());

  List<Opportunity> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetchAll();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } on ApiException {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    // Mới nhất trước. Tin thiếu createdAt xuống cuối chứ không nhảy lên đầu:
    // thiếu dữ liệu không phải lý do để được ưu tiên.
    final recent = [..._items]..sort((a, b) {
        final x = a.createdAt, y = b.createdAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    final top = recent.take(3).toList();

    final jobs = _items.where((e) => !e.isClub).length;
    final clubs = _items.length - jobs;

    // SafeArea bắt buộc: tab này không có AppBar, mà IndexedStack trong shell
    // trải sát mép trên. Thiếu nó thì tiêu đề đè lên đồng hồ và pin.
    // bottom: false vì thanh điều hướng đã tự chừa phần dưới.
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Np.gutter, Np.s6, Np.gutter, Np.s10),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SectionLabel('nextplease'),
          const SizedBox(height: Np.s4),
          Text(
            widget.isGuest ? 'Xin chào 👋' : 'Hôm nay có gì mới?',
            style: NpType.display.copyWith(fontSize: 34, color: c.ink),
          ),
          const SizedBox(height: Np.s2),
          Text(
            'Cơ hội thật, minh chứng thật.',
            style: NpType.body.copyWith(color: c.muted),
          ),

          const SizedBox(height: Np.s8),
          Row(
            children: [
              Expanded(child: _Stat(value: '$jobs', label: 'Doanh nghiệp',
                  loading: _loading)),
              const SizedBox(width: Np.s3),
              Expanded(child: _Stat(value: '$clubs', label: 'CLB & Đoàn hội',
                  loading: _loading)),
            ],
          ),

          const SizedBox(height: Np.s8),
          Row(
            children: [
              const SectionLabel('Mới nhất'),
              const Spacer(),
              GestureDetector(
                onTap: widget.onSeeAll,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text('Xem tất cả',
                        style: NpType.meta.copyWith(
                          color: c.acidText,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: c.acidText),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Np.s4),

          if (_loading)
            _Skeleton(count: 2)
          else if (top.isEmpty)
            Container(
              padding: const EdgeInsets.all(Np.s5),
              decoration: Np.card(c),
              child: Text('Chưa có cơ hội nào.',
                  style: NpType.meta.copyWith(color: c.muted)),
            )
          else
            for (final item in top) ...[
              OpportunityCard(
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
              ),
              const SizedBox(height: Np.s3),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.loading,
  });

  final String value;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loading ? '—' : value,
            style: NpType.display.copyWith(fontSize: 30, color: c.acidText),
          ),
          const SizedBox(height: Np.s1),
          Text(label, style: NpType.meta.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}

/// Khung xám thay cho vòng quay tải.
///
/// Khung giữ đúng chiều cao thẻ thật, nên lúc dữ liệu về thì bố cục không nhảy
/// — thứ khó chịu nhất khi mở một trang có nhiều khối.
class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          Container(
            height: 168,
            decoration: Np.card(c),
          ),
          const SizedBox(height: Np.s3),
        ],
      ],
    );
  }
}
