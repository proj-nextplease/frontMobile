import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'gamification_store.dart';

/// Nhiệm vụ hôm nay và tuần này.
///
/// ─── Vì sao nó đáng nằm ở trang chủ ──────────────────────────────────────
/// /me/gamification vẫn trả `dailyQuests` và `weeklyQuests` từ đầu, nhưng app
/// đọc xong rồi VỨT ĐI. Dữ liệu đã có, phần chơi của sản phẩm đã có, chỉ là
/// chưa bao giờ hiện ra ở đâu cả.
///
/// Đặt ở trang chủ vì trang chủ trả lời "hôm nay nên làm gì" — và đây đúng là
/// một danh sách việc nên làm hôm nay, do chính hệ thống đề ra.
class QuestBoard extends StatefulWidget {
  const QuestBoard({super.key, required this.store});
  final GamificationStore store;

  @override
  State<QuestBoard> createState() => _QuestBoardState();
}

class _QuestBoardState extends State<QuestBoard> {
  /// Khoá đang gọi mạng. Chặn bấm hai lần vào cùng một nhiệm vụ — nhận thưởng
  /// hai lần thì backend bỏ qua lần sau, nhưng nút nhấp nháy trông như hỏng.
  final _busy = <String>{};

  /// Nhiệm vụ vừa nhận xong, giữ lại để hiện "Đã nhận +N EXP" trước khi biến
  /// mất. Không có bước này thì dòng đó lặng lẽ bốc hơi và người dùng không
  /// chắc mình vừa bấm trúng hay không — mà đây chính là khoảnh khắc phần
  /// thưởng, thứ đáng được thấy nhất trong cả phần chơi.
  DailyQuest? _justClaimed;
  Timer? _clearClaimed;

  @override
  void dispose() {
    _clearClaimed?.cancel();
    super.dispose();
  }

  Future<void> _claim(DailyQuest q) async {
    if (_busy.contains(q.key)) return;
    setState(() => _busy.add(q.key));
    final err = await widget.store.claim(q);
    if (!mounted) return;
    setState(() => _busy.remove(q.key));

    if (err == null) {
      setState(() => _justClaimed = q);
      _clearClaimed?.cancel();
      _clearClaimed = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _justClaimed = null);
      });
      return;
    }

    final c = Np.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: c.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Np.rSm)),
      content:
          Text(err, style: NpType.body.copyWith(fontSize: 14, color: Colors.white)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final s = widget.store;

    // Chỉ hiện nhiệm vụ CHƯA nhận thưởng. Giữ lại những cái đã nhận thì danh
    // sách dài dần suốt ngày và phần còn việc bị đẩy xuống dưới.
    final open = [...s.daily, ...s.weekly].where((q) => !q.claimed).toList();

    // Xong rồi thì lên đầu — đó là thứ chỉ cần một cú bấm để lấy EXP.
    open.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? -1 : 1;
      return b.ratio.compareTo(a.ratio);
    });
    var shown = open.take(3).toList();

    // Dòng vừa nhận đã bị lọc khỏi `open` (claimed = true), nhưng phải giữ
    // nó trên màn thêm một nhịp để người dùng thấy phần thưởng.
    final claimed = _justClaimed;
    if (claimed != null) shown = [claimed, ...shown.take(2)];

    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.streak > 0) ...[
          _StreakCard(store: s),
          const SizedBox(height: Np.s4),
        ],
        for (final q in shown) ...[
          _QuestRow(
            quest: q,
            busy: _busy.contains(q.key),
            justClaimed: claimed?.key == q.key,
            onClaim: () => _claim(q),
          ),
          const SizedBox(height: Np.s2),
        ],
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.store});
  final GamificationStore store;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final s = store;
    final isNewRecord = s.streak >= s.longestStreak && s.streak > 1;
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1 = Mon, 7 = Sun
    const weekLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      padding: const EdgeInsets.all(Np.s4),
      decoration: BoxDecoration(
        color: c.surfaceHi,
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6A00).withValues(alpha: 0.18),
            const Color(0xFFFF9500).withValues(alpha: 0.05),
            c.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Np.rLg),
        border: Border.all(
          color: const Color(0xFFFF7A00).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5722).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFF3D00)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: NpIco(NpIcon.flame, size: 24, color: Colors.white),
                ),
              ),
              const SizedBox(width: Np.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'CHUỖI ${s.streak} NGÀY',
                          style: NpType.title.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: const Color(0xFFFF9E00),
                          ),
                        ),
                        if (isNewRecord) ...[
                          const SizedBox(width: Np.s2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3D00).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(Np.rPill),
                              border: Border.all(
                                color: const Color(0xFFFF3D00).withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              'KỶ LỤC 🔥',
                              style: NpType.meta.copyWith(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFF5722),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.longestStreak > s.streak
                          ? 'Kỷ lục: ${s.longestStreak} ngày liên tiếp'
                          : 'Đang duy trì chuỗi tốt nhất của bạn!',
                      style: NpType.meta.copyWith(
                        fontSize: 12,
                        color: c.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.45),
                  ),
                ),
                child: const Text(
                  'RỰC LỬA',
                  style: TextStyle(
                    color: Color(0xFFFF9E00),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Np.s3 + 2),
          Container(height: 1, color: c.line),
          const SizedBox(height: Np.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayNum = index + 1; // 1 to 7
              final isToday = (dayNum == todayWeekday);
              final isPastOrToday = (dayNum <= todayWeekday);
              final isActive = isPastOrToday && ((todayWeekday - dayNum) < s.streak);
              final label = weekLabels[index];

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFFF7A00).withValues(alpha: 0.22)
                            : isToday
                                ? c.surface
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(Np.rSm),
                        border: Border.all(
                          color: isToday
                              ? const Color(0xFFFF9E00)
                              : isActive
                                  ? const Color(0xFFFF7A00).withValues(alpha: 0.5)
                                  : c.line,
                          width: isToday ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: isActive
                            ? const NpIco(NpIcon.flame, size: 15, color: Color(0xFFFF9E00))
                            : isToday
                                ? const NpIco(NpIcon.flame, size: 15, color: Color(0xFFFF5722))
                                : Text(
                                    '•',
                                    style: TextStyle(
                                      color: c.faint,
                                      fontSize: 14,
                                      height: 1,
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: NpType.meta.copyWith(
                        fontSize: 10.5,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isToday
                            ? const Color(0xFFFF9E00)
                            : isActive
                                ? c.ink
                                : c.faint,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.quest,
    required this.busy,
    required this.justClaimed,
    required this.onClaim,
  });

  final DailyQuest quest;
  final bool busy;
  final bool justClaimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final done = quest.completed;

    if (justClaimed) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
            horizontal: Np.s4, vertical: Np.s4 + 2),
        decoration: BoxDecoration(
          color: c.acid.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(Np.rMd),
        ),
        child: Row(
          children: [
            NpIco(NpIcon.bolt, size: 18, color: c.acidText),
            const SizedBox(width: Np.s3),
            Expanded(
              child: Text('Đã nhận +${quest.exp} EXP',
                  style: NpType.body.copyWith(
                    fontSize: 14.5,
                    color: c.acidText,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            Text(quest.title,
                style: NpType.meta.copyWith(fontSize: 12, color: c.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Np.s4, vertical: Np.s3 + 2),
      decoration: Np.card(c, radius: Np.rMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(quest.title,
                          style: NpType.body.copyWith(
                            fontSize: 14.5,
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: Np.s2),
                    // Nhãn phạm vi trên TỪNG dòng, vì một danh sách trộn cả
                    // ngày lẫn tuần thì không tiêu đề chung nào nói đúng được.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Np.s2, vertical: 1),
                      decoration: BoxDecoration(
                        color: c.surfaceHi,
                        borderRadius: BorderRadius.circular(Np.rPill),
                        border: Border.all(color: c.line),
                      ),
                      child: Text(
                        quest.scope.toUpperCase() == 'WEEKLY'
                            ? 'Tuần'
                            : 'Hôm nay',
                        style: NpType.meta
                            .copyWith(fontSize: 10, color: c.muted),
                      ),
                    ),
                    const SizedBox(width: Np.s2),
                    Text('+${quest.exp} EXP',
                        style: NpType.meta.copyWith(
                          fontSize: 11.5,
                          color: c.acidText,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
                const SizedBox(height: Np.s2),
                // Vạch tiến độ thay cho dòng mô tả: "2/3" nói đúng điều cần
                // biết, còn mô tả thì lặp lại tiêu đề bằng nhiều chữ hơn.
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Np.rPill),
                        child: LinearProgressIndicator(
                          value: quest.ratio,
                          minHeight: 4,
                          backgroundColor: c.line,
                          valueColor: AlwaysStoppedAnimation(c.acid),
                        ),
                      ),
                    ),
                    const SizedBox(width: Np.s2),
                    Text('${quest.progress}/${quest.target}',
                        style: NpType.meta
                            .copyWith(fontSize: 11.5, color: c.faint)),
                  ],
                ),
              ],
            ),
          ),
          if (done) ...[
            const SizedBox(width: Np.s3),
            GestureDetector(
              onTap: busy ? null : onClaim,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: Np.s4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: busy ? c.surface : c.acid,
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: busy ? Border.all(color: c.line) : null,
                ),
                child: Text(busy ? '…' : 'Nhận',
                    style: NpType.meta.copyWith(
                      fontSize: 13,
                      color: busy ? c.faint : c.onAcid,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
