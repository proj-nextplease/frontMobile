import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/opportunity_labels.dart';
import 'application_item.dart';

/// Danh sách đơn đã nộp.
///
/// Gộp đơn tin tuyển dụng và đơn quest vào một danh sách, sắp theo ngày nộp.
/// Người dùng không nghĩ theo "đơn job" và "đơn quest" — họ nghĩ "mình đã nộp
/// những đâu rồi", nên tách hai tab ở đây chỉ tạo thêm một bước bấm.
class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  final _api = ApiClient();
  List<ApplicationItem> _items = const [];
  bool _loading = true;
  String? _error;

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

    // Chịu lỗi từng phần: một trong hai endpoint hỏng thì vẫn hiện được nửa
    // còn lại. Chỉ khi cả hai cùng hỏng mới coi là lỗi.
    final res = await Future.wait([
      _try(() => _api.get('/me/applications')),
      _try(() => _api.get('/me/quest-applications')),
    ]);

    if (!mounted) return;
    if (res[0] == null && res[1] == null) {
      setState(() {
        _loading = false;
        _error = 'Không tải được danh sách đơn.';
      });
      return;
    }

    final list = <ApplicationItem>[
      ...?res[0]?.whereType<Map<String, dynamic>>().map(ApplicationItem.fromJob),
      ...?res[1]
          ?.whereType<Map<String, dynamic>>()
          .map(ApplicationItem.fromQuest),
    ]..sort((a, b) {
        final x = a.appliedAt, y = b.appliedAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });

    setState(() {
      _items = list;
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
    final open = _items.where((a) => kOpenStatuses.contains(a.status)).length;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Np.gutter,
        title: Text('Đơn đã nộp', style: NpType.h1.copyWith(color: c.ink)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: c.acidText,
        backgroundColor: c.surfaceHi,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                    color: c.acidText, strokeWidth: 2.4))
            : _error != null
                ? _Note(text: _error!)
                : _items.isEmpty
                    ? _Note(
                        text: 'Bạn chưa nộp đơn nào.\n'
                            'Mở một cơ hội và bấm Ứng tuyển để bắt đầu.')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                            Np.gutter, Np.s2, Np.gutter, Np.s10),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (open > 0) ...[
                            Text('$open đơn đang chờ phản hồi',
                                style: NpType.meta.copyWith(color: c.muted)),
                            const SizedBox(height: Np.s4),
                          ],
                          for (final a in _items) ...[
                            _Row(item: a),
                            const SizedBox(height: Np.s2),
                          ],
                        ],
                      ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final ApplicationItem item;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final color = applicationStatusColor(item.status, c);

    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(item.title,
                    style: NpType.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: Np.s3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s2 + 2, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(Np.rPill),
                ),
                child: Text(applicationStatusLabel(item.status),
                    style: NpType.meta.copyWith(
                      fontSize: 11.5,
                      color: color,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              item.companyName,
              if (item.appliedAt != null) 'nộp ${dmy(item.appliedAt)}',
            ].where((s) => s.isNotEmpty).join(' · '),
            style: NpType.meta.copyWith(fontSize: 12, color: c.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Lý do từ chối là thứ người dùng thật sự muốn đọc khi thấy nhãn đỏ.
          // Giấu nó đi và chỉ hiện chữ "Từ chối" là cách chắc chắn làm người
          // ta bực mà không học được gì.
          if (item.status == 'REJECTED' &&
              item.rejectReason != null &&
              item.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: Np.s3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Np.s3),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Np.rSm),
              ),
              child: Text(item.rejectReason!,
                  style: NpType.meta.copyWith(fontSize: 12.5, color: c.ink)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    // ListView chứ không phải Center: RefreshIndicator cần một vùng cuộn được
    // thì mới kéo xuống làm mới được, và màn rỗng là lúc người dùng hay thử
    // kéo nhất.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Np.s10, Np.s10 * 2, Np.s10, Np.s10),
      children: [
        Text(text,
            style: NpType.meta.copyWith(color: c.muted),
            textAlign: TextAlign.center),
      ],
    );
  }
}
