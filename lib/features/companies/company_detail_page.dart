import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/design.dart';
import '../../core/widgets.dart';
import '../jobs/opportunity.dart';
import '../jobs/opportunity_card.dart';
import '../jobs/opportunity_detail_page.dart';
import 'companies_store.dart';
import 'company.dart';
import 'follow_button.dart';

/// Trang của một đối tác: giới thiệu, liên kết, và các cơ hội đang mở.
class CompanyDetailPage extends StatefulWidget {
  const CompanyDetailPage({super.key, required this.company});
  final Company company;

  @override
  State<CompanyDetailPage> createState() => _CompanyDetailPageState();
}

class _CompanyDetailPageState extends State<CompanyDetailPage> {
  final _api = ApiClient();
  late Company _c = widget.company;

  List<Opportunity> _open = const [];
  bool _loadingOpen = true;

  final _store = CompaniesStore.instance;

  /// Trạng thái theo dõi lần cuối đã biết, để nhận ra người dùng vừa bấm nút.
  ///
  /// KHÔNG dùng `late ... = ...`: Dart khởi tạo lười, nên giá trị chỉ được
  /// tính ở lần đọc đầu tiên — tức bên trong _onStore, sau khi kho đã đổi.
  /// Lúc đó nó luôn bằng trạng thái mới, hàm thoát sớm và số người theo dõi
  /// không bao giờ được nạp lại.
  bool _wasFollowing = false;

  @override
  void initState() {
    super.initState();
    _wasFollowing = _store.isFollowing(widget.company.id);
    _store.addListener(_onStore);
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  /// Theo dõi/bỏ theo dõi làm ĐỔI followerCount, nhưng con số đó nằm trong
  /// /companies/{id} chứ không phải trong kho. Không nạp lại thì màn hình ghi
  /// "1 người theo dõi" ngay sau khi người dùng vừa bỏ theo dõi — một con số
  /// sai nằm ngay dưới cái nút vừa bấm.
  void _onStore() {
    final now = _store.isFollowing(widget.company.id);
    if (now == _wasFollowing || _store.pending.contains(widget.company.id)) {
      return;
    }
    _wasFollowing = now;
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final fresh = await _store.detail(_c.id);
    if (!mounted || fresh == null) return;
    setState(() => _c = fresh);
  }

  Future<void> _load() async {
    // Chi tiết và danh sách cơ hội gọi song song, và chịu lỗi riêng: không
    // lấy được followerCount thì vẫn phải hiện được các tin đang mở.
    final results = await Future.wait([
      CompaniesStore.instance.detail(_c.id),
      _fetchOpen(),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0] is Company) _c = results[0] as Company;
      _open = results[1] as List<Opportunity>;
      _loadingOpen = false;
    });
  }

  Future<List<Opportunity>> _fetchOpen() async {
    final lists = await Future.wait([
      _tryList('/jobs', {'companyId': _c.id, 'limit': 30}),
      _tryList('/quests', {'companyId': _c.id}),
    ]);
    return [
      ...lists[0].map(Opportunity.fromJob),
      ...lists[1].map(Opportunity.fromQuest),
    ];
  }

  Future<List<Map<String, dynamic>>> _tryList(
      String path, Map<String, dynamic> q) async {
    try {
      final data = await _api.get(path, query: q);
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    } on ApiException {
      // Một trong hai hỏng thì vẫn hiện được cái còn lại.
    }
    return const [];
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(titleSpacing: Np.gutter, title: const SizedBox.shrink()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Np.gutter, 0, Np.gutter, Np.navInset),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogo(url: _c.logoUrl, name: _c.name, size: 64),
              const SizedBox(width: Np.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_c.name,
                        style: NpType.h1.copyWith(color: c.ink)),
                    const SizedBox(height: Np.s1),
                    Text(
                      _c.schoolName == null
                          ? companyTypeLabel(_c.type)
                          : '${companyTypeLabel(_c.type)} · ${_c.schoolName}',
                      style: NpType.meta.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Np.s4),

          Row(
            children: [
              FollowButton(companyId: _c.id),
              const SizedBox(width: Np.s3),
              if (_c.followerCount != null)
                Text('${_c.followerCount} người theo dõi',
                    style: NpType.meta.copyWith(color: c.muted)),
            ],
          ),

          if (_c.description != null) ...[
            const SizedBox(height: Np.s6),
            const SectionLabel('Giới thiệu'),
            const SizedBox(height: Np.s2),
            Text(_c.description!, style: NpType.body.copyWith(color: c.ink)),
          ],

          if (_c.websiteUrl != null || _c.fanpageUrl != null) ...[
            const SizedBox(height: Np.s5),
            Wrap(
              spacing: Np.s2,
              runSpacing: Np.s2,
              children: [
                if (_c.websiteUrl != null)
                  _LinkChip(
                      label: 'Website', onTap: () => _openLink(_c.websiteUrl!)),
                if (_c.fanpageUrl != null)
                  _LinkChip(
                      label: 'Fanpage', onTap: () => _openLink(_c.fanpageUrl!)),
              ],
            ),
          ],

          const SizedBox(height: Np.s6),
          SectionLabel(_loadingOpen
              ? 'Cơ hội đang mở'
              : 'Cơ hội đang mở · ${_open.length}'),
          const SizedBox(height: Np.s3),

          if (_loadingOpen)
            _Note('Đang tải…')
          else if (_open.isEmpty)
            _Note('Đối tác này chưa có cơ hội nào đang mở.\n'
                'Theo dõi để được báo khi có tin mới.')
          else
            for (final o in _open)
              Padding(
                padding: const EdgeInsets.only(bottom: Np.s3),
                child: OpportunityCard(
                  item: o,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          OpportunityDetailPage(summary: o, isGuest: false))),
                ),
              ),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Np.rPill),
          border: Border.all(color: c.line),
        ),
        child: Text(label,
            style: NpType.meta.copyWith(
                color: c.acidText, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: Np.s8),
      decoration: Np.card(c),
      child: Text(text,
          textAlign: TextAlign.center,
          style: NpType.meta.copyWith(color: c.muted)),
    );
  }
}
