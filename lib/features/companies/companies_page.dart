import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../core/np_icons.dart';
import '../../core/widgets.dart';
import 'companies_store.dart';
import 'company.dart';
import 'company_detail_page.dart';
import 'follow_button.dart';

/// Danh bạ đối tác: doanh nghiệp, CLB và đơn vị trường đã được duyệt.
class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key, this.followedOnly = false});

  /// Mở thẳng vào phần đang theo dõi, dùng khi vào từ tab Hồ sơ.
  final bool followedOnly;

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  final _store = CompaniesStore.instance;
  final _search = TextEditingController();
  late bool _onlyFollowed = widget.followedOnly;

  @override
  void initState() {
    super.initState();
    _store.addListener(_sync);
    _store.hydrate();
  }

  @override
  void dispose() {
    _store.removeListener(_sync);
    _search.dispose();
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  List<Company> get _visible {
    final q = _search.text.trim().toLowerCase();
    var list = _onlyFollowed ? _store.followed : _store.all;
    if (q.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final list = _visible;
    final followedCount = _store.followed.length;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Đối tác', style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Np.gutter, 0, Np.gutter, Np.s3),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: NpType.body.copyWith(color: c.ink),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên',
                hintStyle: NpType.body.copyWith(color: c.faint),
                filled: true,
                fillColor: c.surface,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(Np.s3),
                  child: NpIco(NpIcon.search, size: 18, color: c.faint),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: Np.s3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Np.rPill),
                  borderSide: BorderSide(color: c.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Np.rPill),
                  borderSide: BorderSide(color: c.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Np.rPill),
                  borderSide: BorderSide(color: c.acid),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
            child: Row(
              children: [
                _Tab(
                  label: 'Tất cả',
                  on: !_onlyFollowed,
                  onTap: () => setState(() => _onlyFollowed = false),
                ),
                const SizedBox(width: Np.s2),
                _Tab(
                  label: followedCount > 0
                      ? 'Đang theo dõi · $followedCount'
                      : 'Đang theo dõi',
                  on: _onlyFollowed,
                  onTap: () => setState(() => _onlyFollowed = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: Np.s3),

          Expanded(
            child: RefreshIndicator(
              color: c.acidText,
              backgroundColor: c.surface,
              onRefresh: _store.hydrate,
              child: list.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(Np.gutter),
                      children: [
                        const SizedBox(height: Np.s10),
                        Text(_emptyText(), textAlign: TextAlign.center,
                            style: NpType.body.copyWith(color: c.muted)),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          Np.gutter, 0, Np.gutter, Np.navInset),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Np.s2),
                      itemBuilder: (_, i) => _Row(company: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _emptyText() {
    if (!_store.loaded) return 'Đang tải…';
    if (_search.text.trim().isNotEmpty) {
      return 'Không có đối tác nào khớp "${_search.text.trim()}".';
    }
    return _onlyFollowed
        ? 'Bạn chưa theo dõi đối tác nào.\n'
            'Theo dõi để thấy tin mới của họ trước.'
        : 'Chưa có đối tác nào được duyệt.';
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
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
          color: on ? c.acid : c.surface,
          borderRadius: BorderRadius.circular(Np.rPill),
          border: Border.all(color: on ? c.acid : c.line),
        ),
        child: Text(label,
            style: NpType.meta.copyWith(
                fontWeight: FontWeight.w600,
                color: on ? c.onAcid : c.muted)),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.company});
  final Company company;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CompanyDetailPage(company: company))),
      child: Container(
        padding: const EdgeInsets.all(Np.s4),
        decoration: Np.card(c, radius: Np.rMd),
        child: Row(
          children: [
            CompanyLogo(url: company.logoUrl, name: company.name, size: 42),
            const SizedBox(width: Np.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company.name,
                      style: NpType.body.copyWith(
                          color: c.ink, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    company.schoolName == null
                        ? companyTypeLabel(company.type)
                        : '${companyTypeLabel(company.type)} · ${company.schoolName}',
                    style: NpType.meta.copyWith(color: c.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Np.s2),
            FollowButton(companyId: company.id, compact: true),
          ],
        ),
      ),
    );
  }
}
