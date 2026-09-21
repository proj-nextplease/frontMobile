import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'opportunities_repository.dart';
import 'opportunity.dart';
import 'opportunity_card.dart';
import 'opportunity_detail_page.dart';

/// Tìm kiếm cơ hội.
///
/// Lọc trên danh sách ĐÃ NẠP trong bộ nhớ chứ không gọi API mỗi lần gõ. Hai lý
/// do: toàn bộ dữ liệu vốn đã tải sẵn cho tab Cơ hội, và gọi mạng theo từng
/// phím gõ sẽ cần chống dội, huỷ yêu cầu cũ, xử lý phản hồi về sai thứ tự —
/// cả một mớ phức tạp cho thứ mà lọc tại chỗ giải quyết tức thì.
///
/// Khi số cơ hội vượt vài trăm thì phải chuyển sang tìm ở server, và lúc đó
/// endpoint GET /jobs đã có sẵn tham số `query`.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.isGuest, this.onSignIn});

  final bool isGuest;
  final VoidCallback? onSignIn;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final _repo = OpportunitiesRepository(ApiClient());
  final _controller = TextEditingController();
  final _focus = FocusNode();

  List<Opportunity> _all = OpportunitiesRepository.cached ?? const [];
  String _q = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Bật bàn phím ngay: người dùng vừa chủ động bấm nút tìm kiếm, bắt họ chạm
    // thêm một lần nữa vào ô nhập là thừa.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    if (_all.isEmpty) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.fetchAll();
      if (mounted) setState(() => _all = data);
    } on ApiException {
      // Ô tìm kiếm không có gì để hiện nếu hỏng; trạng thái rỗng bên dưới đã
      // nói đủ.
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Opportunity> get _results {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _all.where((o) {
      final hay = '${o.title} ${o.companyName} ${o.location ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final results = _results;
    final typed = _q.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          cursorColor: c.acidText,
          style: NpType.body.copyWith(fontSize: 17, color: c.ink),
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Tìm việc, công ty, địa điểm…',
            hintStyle: NpType.body.copyWith(fontSize: 17, color: c.muted),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (typed)
            IconButton(
              icon: Icon(Icons.close_rounded, color: c.muted),
              onPressed: () {
                _controller.clear();
                setState(() => _q = '');
              },
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: c.acidText, strokeWidth: 2.4))
          : !typed
              ? _Hint(total: _all.length)
              : results.isEmpty
                  ? _Empty(query: _q.trim())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          Np.gutter, Np.s3, Np.gutter, Np.s10),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Np.s3),
                      itemBuilder: (_, i) => OpportunityCard(
                        item: results[i],
                        isGuest: widget.isGuest,
                        onNeedSignIn: widget.onSignIn,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OpportunityDetailPage(
                              summary: results[i],
                              isGuest: widget.isGuest,
                              onSignIn: widget.onSignIn,
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Np.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 40, color: c.faint),
            const SizedBox(height: Np.s4),
            Text(
              'Đang có $total cơ hội',
              style: NpType.title.copyWith(color: c.ink),
            ),
            const SizedBox(height: Np.s2),
            Text(
              'Gõ tên việc, tên công ty hoặc địa điểm.',
              textAlign: TextAlign.center,
              style: NpType.meta.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Np.gutter),
        child: Text(
          'Không tìm thấy cơ hội nào khớp với "$query".',
          textAlign: TextAlign.center,
          style: NpType.meta.copyWith(color: c.muted),
        ),
      ),
    );
  }
}
