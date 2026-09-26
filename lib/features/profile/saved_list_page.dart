import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/mascot.dart';
import '../../core/theme.dart';
import '../jobs/opportunity.dart';
import '../jobs/opportunity_card.dart';
import '../jobs/opportunity_detail_page.dart';
import '../jobs/saved_store.dart';

/// Danh sách tin đã lưu.
///
/// Nạp từ /me/saved-jobs và /me/saved-quests chứ KHÔNG lọc lại danh sách cơ
/// hội đang có trong bộ đệm: hai endpoint kia đã loại sẵn tin đã đóng và tin
/// quá hạn, còn bộ đệm thì chỉ chứa 60 tin đầu của /jobs — tin đã lưu nằm
/// ngoài 60 tin đó sẽ biến mất không dấu vết.
class SavedListPage extends StatefulWidget {
  const SavedListPage({super.key});

  @override
  State<SavedListPage> createState() => _SavedListPageState();
}

class _SavedListPageState extends State<SavedListPage> {
  final _api = ApiClient();
  List<Opportunity> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SavedStore.instance.addListener(_onStore);
    _load();
  }

  @override
  void dispose() {
    SavedStore.instance.removeListener(_onStore);
    super.dispose();
  }

  /// Bỏ lưu ngay trên màn này thì tin phải rời khỏi danh sách. Không nghe kho
  /// thì trái tim tắt đi nhưng thẻ vẫn nằm đó, trông như thao tác chưa ăn.
  void _onStore() {
    if (!mounted) return;
    setState(() => _items =
        _items.where((o) => SavedStore.instance.isSaved(o)).toList());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await Future.wait([
      _try(() => _api.get('/me/saved-jobs')),
      _try(() => _api.get('/me/saved-quests')),
    ]);

    if (!mounted) return;
    if (res[0] == null && res[1] == null) {
      setState(() {
        _loading = false;
        _error = 'Không tải được danh sách đã lưu.';
      });
      return;
    }

    setState(() {
      _items = <Opportunity>[
        ...?res[0]?.whereType<Map<String, dynamic>>().map(Opportunity.fromJob),
        ...?res[1]
            ?.whereType<Map<String, dynamic>>()
            .map(Opportunity.fromQuest),
      ];
      _loading = false;
    });
  }

  Future<List<dynamic>?> _try(Future<dynamic> Function() f) async {
    try {
      final d = await f();
      return d is List ? d : const [];
    } on ApiException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Tin đã lưu', style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                    color: c.acidText, strokeWidth: 2.4))
            : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: Np.s8),
                      MascotEmptyState(
                        mascotId: 'frog',
                        title: _error ?? 'Chưa lưu tin nào',
                        description: _error != null
                            ? 'Vui lòng vuốt xuống để thử tải lại.'
                            : 'Bấm biểu tượng trái tim trên các cơ hội việc làm & nhiệm vụ để lưu lại xem sau.',
                        actionLabel: 'Khám phá cơ hội ngay',
                        onAction: () => Navigator.of(context).pop(),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Np.gutter, Np.s2, Np.gutter, Np.s10),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Np.s3),
                    itemBuilder: (_, i) => OpportunityCard(
                      item: _items[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          // Màn này chỉ tới được khi đã đăng nhập (nó nằm
                          // trong tab Hồ sơ của người có phiên), nên isGuest
                          // luôn false và không cần lối mời đăng nhập.
                          builder: (_) => OpportunityDetailPage(
                            summary: _items[i],
                            isGuest: false,
                            onSignIn: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
