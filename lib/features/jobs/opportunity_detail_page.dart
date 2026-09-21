import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'opportunities_repository.dart';
import 'applied_store.dart';
import 'eligibility.dart';
import 'opportunity.dart';
import 'opportunity_labels.dart';
import 'save_button.dart';

/// Màn hình chi tiết một cơ hội.
///
/// Nhận sẵn bản tóm tắt từ danh sách rồi mới nạp thêm chi tiết. Nhờ vậy màn
/// hình hiện NGAY với tiêu đề, lương, mô tả — người dùng không phải nhìn vòng
/// quay tải trong khi những thứ đó đã nằm sẵn trong bộ nhớ. Chỉ vài trường phụ
/// (số lượng tuyển, kỹ năng) là xuất hiện muộn hơn một nhịp.
class OpportunityDetailPage extends StatefulWidget {
  const OpportunityDetailPage({
    super.key,
    required this.summary,
    required this.isGuest,
    this.onSignIn,
  });

  final Opportunity summary;
  final bool isGuest;
  final VoidCallback? onSignIn;

  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  late final _repo = OpportunitiesRepository(ApiClient());
  late Opportunity _item = widget.summary;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _repo.fetchDetail(widget.summary).then((full) {
      if (mounted) setState(() => _item = full);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final it = _item;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: c.ink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Np.s2),
              child: SaveButton(
                item: it,
                isGuest: widget.isGuest,
                onNeedSignIn: widget.onSignIn,
                size: 24,
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Np.gutter, 0, Np.gutter, Np.s10),
          children: [
            _Header(item: it),
            const SizedBox(height: Np.s6),
            _Facts(item: it),
            const SizedBox(height: Np.s8),

            const SectionLabel('Mô tả'),
            const SizedBox(height: Np.s3),
            Text(
              it.description.trim().isEmpty
                  ? 'Tổ chức chưa viết mô tả cho tin này.'
                  : it.description.trim(),
              style: NpType.body.copyWith(
                color: it.description.trim().isEmpty ? c.muted : c.ink,
                height: 1.62,
              ),
            ),

            if (it.skills.isNotEmpty) ...[
              const SizedBox(height: Np.s8),
              const SectionLabel('Kỹ năng'),
              const SizedBox(height: Np.s3),
              Wrap(
                spacing: Np.s2,
                runSpacing: Np.s2,
                children: [
                  for (final s in it.skills) MetaChip(label: s),
                ],
              ),
            ],

            const SizedBox(height: Np.s8),
            const SectionLabel('Đơn vị đăng'),
            const SizedBox(height: Np.s3),
            _CompanyRow(item: it),
          ],
        ),
        bottomNavigationBar: _ApplyBar(
          eligibility: eligibilityOf(it, isGuest: widget.isGuest),
          applying: _applying,
          onSignIn: widget.onSignIn,
          onApply: _openApplySheet,
        ),
      ),
    );
  }

  Future<void> _openApplySheet() async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplySheet(item: _item),
    );
    if (note == null || !mounted) return;

    setState(() => _applying = true);
    final err = await _repo.apply(_item, note);
    if (err == null) AppliedStore.instance.markApplied(_item);
    if (!mounted) return;
    setState(() => _applying = false);

    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: err == null ? c.surfaceHi : c.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Np.rSm),
        ),
        content: Text(
          err ?? 'Đã nộp đơn. Tổ chức sẽ phản hồi qua thông báo.',
          style: NpType.body.copyWith(
            fontSize: 14,
            color: err == null ? c.ink : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item});
  final Opportunity item;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final hasPay = item.compensation != null && item.compensation! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(item.isQuest ? 'Quest' : 'Tin tuyển dụng'),
            if (item.requiresPremium) ...[
              const SizedBox(width: Np.s3),
              const MetaChip(label: 'Premium', accent: true),
            ],
          ],
        ),
        const SizedBox(height: Np.s4),
        Text(
          item.title,
          style: NpType.h1.copyWith(fontSize: 30, color: c.ink),
        ),
        const SizedBox(height: Np.s4),
        Text(
          item.isQuest
              ? rewardLine(exp: item.expReward, np: item.npReward)
              : salaryLabel(
                  compensation: item.compensation, isQuest: false),
          style: NpType.h1.copyWith(
            fontFamily: 'BeVietnamPro',
            fontVariations: const [],
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: hasPay || item.isQuest ? c.acidText : c.muted,
          ),
        ),
      ],
    );
  }
}

/// Khối thông tin thực tế, hai cột.
///
/// Dùng lưới nhãn/giá trị thay vì một dãy chip: ở đây mỗi con số cần có TÊN
/// của nó. Chip hợp cho thẻ trong danh sách, nơi chỉ cần liếc qua; còn ở trang
/// chi tiết, "2" mà không có chữ "Số lượng" thì vô nghĩa.
class _Facts extends StatelessWidget {
  const _Facts({required this.item});
  final Opportunity item;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final left = daysLeft(item.deadlineAt ?? item.endsAt);

    final facts = <(String, String)>[
      ('Địa điểm', item.isRemote
          ? '${item.location ?? "Không rõ"} · Remote'
          : (item.location ?? 'Không rõ')),
      ('Hình thức', typeLabel(item.typeCode)),
      if (item.isQuest) ...[
        ('Bắt đầu', dmy(item.startsAt)),
        ('Kết thúc', dmy(item.endsAt)),
      ] else
        ('Hạn nộp', dmy(item.deadlineAt)),
      if (item.capacity != null) ('Số lượng', '${item.capacity} người'),
      if (item.minReqRs > 0) ('Uy tín tối thiểu', '${item.minReqRs} RS'),
      ('Đã ứng tuyển', '${item.applicantCount} người'),
    ];

    return Container(
      padding: const EdgeInsets.all(Np.s5),
      decoration: Np.card(c),
      child: Column(
        children: [
          if (left != null) ...[
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: c.acidText),
                const SizedBox(width: Np.s2),
                Text(
                  left == 0 ? 'Hạn cuối là hôm nay' : 'Còn $left ngày',
                  style: NpType.meta.copyWith(
                    color: c.acidText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Np.s4),
            Divider(color: c.line, height: 1),
            const SizedBox(height: Np.s4),
          ],
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const SizedBox(height: Np.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 124,
                  child: Text(facts[i].$1,
                      style: NpType.meta.copyWith(color: c.muted)),
                ),
                Expanded(
                  child: Text(
                    facts[i].$2,
                    style: NpType.meta.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({required this.item});
  final Opportunity item;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: Np.card(c, radius: Np.rMd),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.companyName,
              style: NpType.title.copyWith(color: c.ink),
            ),
          ),
          MetaChip(label: item.isClub ? 'CLB / Tổ chức' : 'Doanh nghiệp'),
        ],
      ),
    );
  }
}

/// Thanh hành động dính đáy.
///
/// Dính đáy chứ không nằm cuối trang: mô tả tin có thể dài vài màn hình, và
/// bắt người dùng cuộn hết mới thấy nút ứng tuyển là chắc chắn mất người.
class _ApplyBar extends StatelessWidget {
  const _ApplyBar({
    required this.eligibility,
    required this.applying,
    required this.onApply,
    this.onSignIn,
  });

  final Eligibility eligibility;
  final bool applying;
  final VoidCallback onApply;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final reason = eligibility.reason;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Np.gutter, Np.s3, Np.gutter,
        Np.s3 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lý do nằm TRÊN nút chứ không phải trong một hộp thoại sau khi bấm.
          // Đây là toàn bộ điểm của thay đổi này: nói trước, không nói sau.
          if (reason != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NpIco(
                  eligibility.blocker == Blocker.applied
                      ? NpIcon.send
                      : NpIcon.bolt,
                  size: 15,
                  color: eligibility.blocker == Blocker.applied
                      ? c.acidText
                      : c.muted,
                ),
                const SizedBox(width: Np.s2),
                Expanded(
                  child: Text(reason,
                      style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted)),
                ),
              ],
            ),
            const SizedBox(height: Np.s3),
          ],
          _button(c),
        ],
      ),
    );
  }

  Widget _button(NpColors c) {
    if (eligibility.blocker == Blocker.guest) {
      return AcidButton(
        label: 'Đăng nhập để ứng tuyển',
        icon: Icons.arrow_forward_rounded,
        onTap: onSignIn ?? () {},
      );
    }
    if (eligibility.canApply) {
      return AcidButton(
        label: 'Ứng tuyển',
        busy: applying,
        icon: Icons.arrow_forward_rounded,
        onTap: onApply,
      );
    }

    // Nút tắt, KHÔNG phải nút ẩn. Ẩn hẳn thì người dùng đi tìm nút ứng tuyển
    // và tưởng app hỏng; để đó mà xám thì họ hiểu ngay là có nút, chỉ chưa
    // dùng được — và dòng lý do phía trên nói vì sao.
    return Container(
      width: double.infinity,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Np.rPill),
        border: Border.all(color: c.line),
      ),
      child: Text(
        switch (eligibility.blocker) {
          Blocker.applied => 'Đã nộp đơn',
          Blocker.expired => 'Đã hết hạn',
          Blocker.reputation => 'Chưa đủ điểm uy tín',
          _ => 'Không nộp được',
        },
        style: NpType.button.copyWith(color: c.faint),
      ),
    );
  }
}

/// Ô nhập lời nhắn, trượt lên từ đáy.
///
/// Lời nhắn để TRỐNG vẫn nộp được — backend không bắt buộc. Ép viết mới được
/// nộp sẽ chặn đúng nhóm người ngại viết, mà họ vẫn có thể là ứng viên phù hợp.
class _ApplySheet extends StatefulWidget {
  const _ApplySheet({required this.item});
  final Opportunity item;

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Padding(
      // Đẩy cả tấm lên trên bàn phím, nếu không ô nhập bị che.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Np.gutter, Np.s5, Np.gutter, Np.s6),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Np.rLg),
          ),
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Nộp đơn'),
            const SizedBox(height: Np.s3),
            Text(widget.item.title,
                style: NpType.title.copyWith(color: c.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: Np.s5),
            TextField(
              controller: _note,
              maxLines: 4,
              maxLength: 1000,
              cursorColor: c.acidText,
              style: NpType.body.copyWith(color: c.ink),
              decoration: InputDecoration(
                hintText: 'Lời nhắn cho nhà tuyển dụng (không bắt buộc)',
                hintStyle: NpType.body.copyWith(color: c.muted),
                counterStyle: NpType.meta.copyWith(color: c.faint),
                filled: true,
                fillColor: c.surfaceHi,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Np.rMd),
                  borderSide: BorderSide(color: c.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Np.rMd),
                  borderSide: BorderSide(color: c.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Np.rMd),
                  borderSide: BorderSide(color: c.acidText, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: Np.s3),
            AcidButton(
              label: 'Gửi đơn',
              icon: Icons.send_rounded,
              onTap: () => Navigator.of(context).pop(_note.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}
