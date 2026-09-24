import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../jobs/opportunity_labels.dart';
import 'application_detail_page.dart';
import 'application_item.dart';
import 'rating_view.dart';

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
                          for (var i = 0; i < _items.length; i++) ...[
                            _Card(
                              item: _items[i],
                              // Đơn MỚI NHẤT mở sẵn, còn lại gập. Mở hết thì
                              // phải cuộn qua vài màn mới thấy đơn thứ ba;
                              // gập hết thì lần nào vào cũng phải bấm thêm
                              // một cái để biết chuyện gì đang xảy ra.
                              initiallyOpen: i == 0,
                              onOpenDetail: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ApplicationDetailPage(
                                        item: _items[i]),
                                  ),
                                );
                                // Rút đơn xong thì trạng thái trong danh sách
                                // phải đổi theo.
                                if (mounted) await _load();
                              },
                            ),
                            const SizedBox(height: Np.s3),
                          ],
                        ],
                      ),
      ),
    );
  }
}

/// Một đơn: đầu thẻ là việc, thân là dòng thời gian gập được.
///
/// Dòng thời gian nằm NGAY trong danh sách chứ không giấu sau một cú bấm:
/// câu hỏi duy nhất của người vừa nộp đơn là "tới đâu rồi", và bắt họ mở từng
/// đơn ra để biết là bắt làm việc thừa.
class _Card extends StatefulWidget {
  const _Card({
    required this.item,
    required this.initiallyOpen,
    required this.onOpenDetail,
  });

  final ApplicationItem item;
  final bool initiallyOpen;
  final VoidCallback onOpenDetail;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final item = widget.item;
    final color = applicationStatusColor(item.status, c);

    return Container(
      decoration: Np.card(c, radius: Np.rLg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Đầu thẻ: việc gì, ở đâu ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(Np.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: NpType.title
                              .copyWith(fontSize: 16, color: c.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(item.companyName,
                          style: NpType.meta.copyWith(color: c.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: Np.s3),
                CompanyLogo(
                    url: item.companyLogo, name: item.companyName, size: 44),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: c.line),

          // ── Thân: trạng thái + dòng thời gian ────────────────────────
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Np.s4, Np.s4, Np.s4, Np.s3),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: Np.s3),
                  Expanded(
                    child: Text(_statusLine(item),
                        style: NpType.body.copyWith(
                          fontSize: 14.5,
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 22, color: c.faint),
                  ),
                ],
              ),
            ),
          ),

          // Đánh giá nằm NGOÀI phần gập.
          //
          // Lần đầu tôi đặt nó bên trong, rồi tự viết chú thích "tin vui nên
          // tìm tới người dùng chứ không nằm chờ được tìm" — trong khi chỉ
          // thẻ đầu tiên mở sẵn (initiallyOpen: i == 0), nên với mọi thẻ còn
          // lại nó bị giấu đúng vào chỗ phải đi tìm. Đây là thứ người ta mở
          // app ra để xem; nó phải thấy được mà không cần bấm gì.
          if (item.ratingScore != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Np.s4, 0, Np.s4, Np.s3),
              child: Row(
                children: [
                  StarRow(score: item.ratingScore!),
                  const SizedBox(width: Np.s2),
                  Expanded(
                    child: Text(
                      item.ratingComment?.isNotEmpty == true
                          ? '“${item.ratingComment!}”'
                          : 'Tổ chức đã đánh giá bạn',
                      style: NpType.meta
                          .copyWith(fontSize: 12.5, color: c.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Np.s4, 0, Np.s4, Np.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.history.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: Np.s1),
                            child: Text(
                              item.appliedAt == null
                                  ? 'Chưa có diễn biến nào.'
                                  : 'Đã nộp ${dmy(item.appliedAt)}',
                              style: NpType.meta.copyWith(color: c.muted),
                            ),
                          )
                        else
                          _Timeline(steps: item.history),

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
                                style: NpType.meta
                                    .copyWith(fontSize: 12.5, color: c.ink)),
                          ),
                        ],

                        const SizedBox(height: Np.s4),
                        // Chỗ này KHÔNG đặt "Hỏi kết quả" hay "Đã được phản
                        // hồi": hệ thống không có luồng nào đứng sau hai việc
                        // đó, và một cái nút không làm gì tệ hơn không có nút.
                        // Chỉ hai việc app thật sự làm được.
                        Row(
                          children: [
                            Expanded(
                              child: _Action(
                                label: 'Xem hồ sơ đã nộp',
                                onTap: widget.onOpenDetail,
                              ),
                            ),
                            if (item.canWithdraw) ...[
                              const SizedBox(width: Np.s2),
                              Expanded(
                                child: _Action(
                                  label: 'Rút đơn',
                                  danger: true,
                                  onTap: widget.onOpenDetail,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// Nói TRẠNG THÁI NGHĨA LÀ GÌ, không lặp lại cái nhãn. "Đã nộp" là một từ;
  /// "nhà tuyển dụng chưa mở đơn" là một thông tin.
  String _statusLine(ApplicationItem item) => switch (item.status) {
        'SUBMITTED' => 'Đơn đã gửi, nhà tuyển dụng chưa mở',
        'VIEWED' => 'Nhà tuyển dụng đã mở đơn của bạn',
        'SHORTLISTED' => 'Bạn đã vào vòng trong',
        'ACCEPTED' => 'Bạn được nhận',
        'REJECTED' => 'Đơn không được chọn lần này',
        'WITHDRAWN' => 'Bạn đã rút đơn này',
        'COMPLETED' => 'Công việc đã hoàn thành',
        _ => applicationStatusLabel(item.status),
      };
}

/// Dòng thời gian, cũ trước mới sau.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});
  final List<StatusStep> steps;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        // Chỉ mốc MỚI NHẤT được tô. Tô hết thì không đọc ra
                        // được đơn đang ở đâu.
                        color: i == steps.length - 1 ? c.acid : c.line,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i != steps.length - 1)
                      Expanded(child: Container(width: 1.5, color: c.line)),
                  ],
                ),
                const SizedBox(width: Np.s3),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: i == steps.length - 1 ? 0 : Np.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(applicationStatusLabel(steps[i].status),
                            style: NpType.body.copyWith(
                              fontSize: 14,
                              color: c.ink,
                              fontWeight: FontWeight.w600,
                            )),
                        if (steps[i].at != null)
                          Text(dmy(steps[i].at),
                              style: NpType.meta
                                  .copyWith(fontSize: 12, color: c.muted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Nút viền nhỏ trong thẻ.
class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap, this.danger = false});
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final tint = danger ? c.danger : c.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Np.rPill),
          border: Border.all(
              color: danger ? c.danger.withValues(alpha: 0.4) : c.line),
        ),
        child: Text(label,
            style: NpType.meta.copyWith(
              fontSize: 13.5,
              color: tint,
              fontWeight: FontWeight.w600,
            )),
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
