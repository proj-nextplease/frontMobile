import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'opportunity.dart';
import 'opportunity_labels.dart';

/// Bộ lọc danh sách cơ hội.
///
/// ─── Vì sao KHÔNG bê nguyên thanh lọc của web ────────────────────────────
/// Web có sáu ô thả xuống nằm ngang một hàng. Trên màn hình rộng thì đọc được
/// cả hàng trong một cái liếc; trên điện thoại sáu ô đó thành một băng chuyền
/// ngang mà người dùng phải cuộn mới biết có những gì — tức là bộ lọc tự giấu
/// chính nó. Nên ở đây gom hết vào MỘT tấm trượt lên, mở bằng một nút duy
/// nhất có số đếm. Người dùng thấy ngay "đang bật mấy bộ lọc" mà không tốn
/// chỗ trên màn danh sách.
///
/// Bốn chiều lọc, chọn theo thứ tự người đi tìm việc thật sự quan tâm. Hai
/// chiều của web bị bỏ là "Đơn vị đăng" (đã có hàng tab Doanh nghiệp / CLB ở
/// ngay trên) và "Số ứng viên" (trên điện thoại không ai lọc theo con số đó,
/// và danh sách hiện chưa đủ lớn để nó có nghĩa).
class OppFilter {
  const OppFilter({
    this.provinces = const {},
    this.types = const {},
    this.remote,
    this.postedWithinDays,
  });

  /// Tỉnh/thành. Rỗng nghĩa là không lọc, KHÔNG phải "không nơi nào".
  final Set<String> provinces;

  /// Mã loại cơ hội (INTERNSHIP, SMALL_EVENT…), không phải nhãn tiếng Việt —
  /// nhãn có thể đổi, mã thì không.
  final Set<String> types;

  /// null = không quan tâm, true = chỉ remote, false = chỉ tại chỗ.
  final bool? remote;

  /// Số ngày kể từ lúc đăng. null = không lọc.
  final int? postedWithinDays;

  bool get isEmpty =>
      provinces.isEmpty && types.isEmpty && remote == null && postedWithinDays == null;

  /// Số chiều đang bật — hiện trên nút để người dùng biết danh sách đã bị cắt.
  int get activeCount =>
      (provinces.isEmpty ? 0 : 1) +
      (types.isEmpty ? 0 : 1) +
      (remote == null ? 0 : 1) +
      (postedWithinDays == null ? 0 : 1);

  OppFilter copyWith({
    Set<String>? provinces,
    Set<String>? types,
    bool? remote,
    int? postedWithinDays,
    bool clearRemote = false,
    bool clearPosted = false,
  }) =>
      OppFilter(
        provinces: provinces ?? this.provinces,
        types: types ?? this.types,
        remote: clearRemote ? null : (remote ?? this.remote),
        postedWithinDays:
            clearPosted ? null : (postedWithinDays ?? this.postedWithinDays),
      );

  bool matches(Opportunity o) {
    if (provinces.isNotEmpty) {
      final p = provinceOf(o);
      // Tin không rút được tỉnh/thành thì KHÔNG khớp bất kỳ lựa chọn địa điểm
      // nào — giữ lại sẽ làm "lọc theo TP.HCM" trả về cả tin không ghi nơi làm.
      if (p == null || !provinces.contains(p)) return false;
    }
    if (types.isNotEmpty && !types.contains(o.typeCode ?? '')) return false;
    if (remote != null && o.isRemote != remote) return false;
    if (postedWithinDays != null) {
      final d = o.createdAt;
      // Tin không có ngày đăng bị LOẠI khi người dùng lọc theo thời gian.
      // Giữ lại thì "đăng trong 7 ngày" sẽ trả về cả những tin không ai biết
      // đăng lúc nào — đúng nghĩa là sai kết quả.
      if (d == null) return false;
      if (DateTime.now().difference(d).inDays > postedWithinDays!) return false;
    }
    return true;
  }
}

/// Rút tỉnh/thành từ chuỗi địa điểm tự do.
///
/// Trường `location` do nhà tuyển dụng tự nhập nên có đủ kiểu: "TP. Hồ Chí
/// Minh", "Hà Nội - Cầu Giấy", "Làm từ xa". Lấy đoạn trước dấu phân cách đầu
/// tiên là đủ gom về một nhóm dùng được, và cố ý KHÔNG dò theo danh sách 63
/// tỉnh — dò cứng như vậy thì mọi cách viết lệch chuẩn đều rơi ra ngoài.
String? provinceOf(Opportunity o) {
  final raw = (o.location ?? '').trim();
  if (raw.isEmpty) return null;
  final head = raw.split(RegExp(r'\s*[-–,/|]\s*')).first.trim();
  if (head.isEmpty) return null;

  // Nhiều tin ghi thẳng "Làm từ xa" / "Remote" vào ô địa điểm. Để nguyên thì
  // nhóm Địa điểm mọc ra một lựa chọn trùng y hệt nhóm Hình thức ngay phía
  // trên — hai nút cùng chữ, cùng kết quả, người dùng không biết chọn cái nào.
  // Trả null để tin đó chỉ lọc được qua nhóm Hình thức.
  if (RegExp(r'remote|từ xa|tu xa', caseSensitive: false).hasMatch(head)) {
    return null;
  }
  return head;
}

const kPostedBuckets = <int, String>{
  3: '3 ngày qua',
  7: '7 ngày qua',
  30: '30 ngày qua',
};

/// Tấm lọc trượt lên. Trả về bộ lọc mới, hoặc null nếu người dùng đóng đi.
///
/// Các lựa chọn được dựng TỪ danh sách đang có chứ không phải từ một bảng cố
/// định: hiện ra một tỉnh không có tin nào thì bấm vào chỉ nhận danh sách
/// rỗng, và người dùng sẽ tưởng app hỏng.
Future<OppFilter?> showOppFilterSheet(
  BuildContext context, {
  required List<Opportunity> source,
  required OppFilter current,
}) {
  return showModalBottomSheet<OppFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(source: source, initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.source, required this.initial});
  final List<Opportunity> source;
  final OppFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late OppFilter _f = widget.initial;

  /// Số tin còn lại nếu áp bộ lọc đang chọn. Hiện ngay trên nút xác nhận để
  /// người dùng không phải đóng tấm này lại mới biết mình vừa lọc mất hết.
  int get _hits => widget.source.where(_f.matches).length;

  List<String> get _provinces {
    final set = widget.source
        .map(provinceOf)
        .whereType<String>()
        .toSet()
        .toList();
    // Sắp theo mã ký tự, bỏ qua hoa/thường. Đây KHÔNG phải thứ tự chữ cái
    // tiếng Việt — "Đà Nẵng" vẫn rơi xuống sau "Vũng Tàu" vì Đ nằm ngoài
    // bảng ASCII. Chấp nhận được khi danh sách chỉ vài tỉnh; nếu sau này dài
    // ra thì cần gói `intl` để so theo locale vi.
    set.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return set;
  }

  List<String> get _types {
    final set = widget.source
        .map((o) => o.typeCode ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    set.sort((a, b) => typeLabel(a).compareTo(typeLabel(b)));
    return set;
  }

  void _toggle(Set<String> set, String v, void Function(Set<String>) apply) {
    final next = {...set};
    if (!next.remove(v)) next.add(v);
    setState(() => apply(next));
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final bottom = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      // Chừa một khoảng trên cùng để vẫn thấy được danh sách phía sau — tấm
      // lọc che kín màn hình sẽ mất cảm giác "đang lọc cái gì".
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Np.rLg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Np.s3),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: c.line,
              borderRadius: BorderRadius.circular(Np.rPill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s4, Np.gutter, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Lọc cơ hội',
                      style: NpType.h1.copyWith(color: c.ink)),
                ),
                if (!_f.isEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _f = const OppFilter()),
                    behavior: HitTestBehavior.opaque,
                    child: Text('Xoá hết',
                        style: NpType.meta.copyWith(
                          color: c.danger,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
              ],
            ),
          ),

          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Np.gutter, Np.s5, Np.gutter, Np.s5),
              children: [
                _Group(
                  label: 'Hình thức',
                  child: Wrap(
                    spacing: Np.s2,
                    runSpacing: Np.s2,
                    children: [
                      _Pick(
                        label: 'Làm từ xa',
                        on: _f.remote == true,
                        onTap: () => setState(() => _f = _f.remote == true
                            ? _f.copyWith(clearRemote: true)
                            : _f.copyWith(remote: true)),
                      ),
                      _Pick(
                        label: 'Tại chỗ',
                        on: _f.remote == false,
                        onTap: () => setState(() => _f = _f.remote == false
                            ? _f.copyWith(clearRemote: true)
                            : _f.copyWith(remote: false)),
                      ),
                    ],
                  ),
                ),

                if (_types.isNotEmpty)
                  _Group(
                    label: 'Loại cơ hội',
                    child: Wrap(
                      spacing: Np.s2,
                      runSpacing: Np.s2,
                      children: [
                        for (final t in _types)
                          _Pick(
                            label: typeLabel(t),
                            on: _f.types.contains(t),
                            onTap: () => _toggle(_f.types, t,
                                (s) => _f = _f.copyWith(types: s)),
                          ),
                      ],
                    ),
                  ),

                if (_provinces.isNotEmpty)
                  _Group(
                    label: 'Địa điểm',
                    child: Wrap(
                      spacing: Np.s2,
                      runSpacing: Np.s2,
                      children: [
                        for (final p in _provinces)
                          _Pick(
                            label: p,
                            on: _f.provinces.contains(p),
                            onTap: () => _toggle(_f.provinces, p,
                                (s) => _f = _f.copyWith(provinces: s)),
                          ),
                      ],
                    ),
                  ),

                _Group(
                  label: 'Mới đăng',
                  last: true,
                  child: Wrap(
                    spacing: Np.s2,
                    runSpacing: Np.s2,
                    children: [
                      for (final e in kPostedBuckets.entries)
                        _Pick(
                          label: e.value,
                          on: _f.postedWithinDays == e.key,
                          onTap: () => setState(() =>
                              _f = _f.postedWithinDays == e.key
                                  ? _f.copyWith(clearPosted: true)
                                  : _f.copyWith(postedWithinDays: e.key)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
                Np.gutter, 0, Np.gutter, bottom + Np.s4),
            child: AcidButton(
              // Số tin nằm ngay trên nút: lọc đến mức không còn gì thì người
              // dùng biết trước khi bấm, thay vì bấm xong mới thấy màn trống.
              label: _hits == 0 ? 'Không có tin nào khớp' : 'Xem $_hits tin',
              onTap: _hits == 0
                  ? () {}
                  : () => Navigator.of(context).pop(_f),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child, this.last = false});
  final String label;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : Np.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: NpType.label.copyWith(color: c.muted)),
          const SizedBox(height: Np.s3),
          child,
        ],
      ),
    );
  }
}

/// Một lựa chọn. Bật thì tô nền nhạt và đổi màu chữ — cố ý KHÔNG dùng dấu
/// tích: dấu tích trong một hàng chip ngang đọc ra như biểu tượng trang trí.
class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s2 + 2),
        decoration: BoxDecoration(
          color: on ? c.acid.withValues(alpha: 0.16) : c.surface,
          borderRadius: BorderRadius.circular(Np.rPill),
          border: Border.all(
            color: on ? c.acid.withValues(alpha: 0.55) : c.line,
          ),
        ),
        child: Text(
          label,
          style: NpType.meta.copyWith(
            fontSize: 13.5,
            color: on ? c.acidText : c.ink,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
