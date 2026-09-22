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

  Future<void> _claim(DailyQuest q) async {
    if (_busy.contains(q.key)) return;
    setState(() => _busy.add(q.key));
    final err = await widget.store.claim(q);
    if (!mounted) return;
    setState(() => _busy.remove(q.key));
    if (err == null) return;

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
    if (open.isEmpty) return const SizedBox.shrink();

    // Xong rồi thì lên đầu — đó là thứ chỉ cần một cú bấm để lấy EXP.
    open.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? -1 : 1;
      return b.ratio.compareTo(a.ratio);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final q in open.take(3)) ...[
          _QuestRow(
            quest: q,
            busy: _busy.contains(q.key),
            onClaim: () => _claim(q),
          ),
          const SizedBox(height: Np.s2),
        ],
        if (s.streak > 0) ...[
          const SizedBox(height: Np.s1),
          Row(
            children: [
              NpIco(NpIcon.flame, size: 15, color: c.acidText),
              const SizedBox(width: Np.s2),
              Text(
                'Chuỗi ${s.streak} ngày'
                '${s.longestStreak > s.streak ? ' · dài nhất ${s.longestStreak}' : ''}',
                style: NpType.meta.copyWith(fontSize: 12.5, color: c.muted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.quest,
    required this.busy,
    required this.onClaim,
  });

  final DailyQuest quest;
  final bool busy;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final done = quest.completed;

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
