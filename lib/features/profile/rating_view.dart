import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../core/np_icons.dart';

/// Hàng sao đánh giá.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.score, this.size = 15});

  /// 1..5.
  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: NpIco(
              i <= score ? NpIcon.starFill : NpIcon.star,
              size: size,
              // Sao chưa đạt vẫn phải THẤY được, nhưng mờ hơn hẳn: vẽ bằng
              // màu đường kẻ thì trên nền thẻ nó gần như biến mất và hàng sao
              // trông như chỉ có 3 cái.
              color: i <= score ? const Color(0xFFF59E0B) : c.faint,
            ),
          ),
      ],
    );
  }
}

/// Khối đánh giá đầy đủ: sao, nhận xét, và một dòng giải thích.
///
/// Dữ liệu này đã nằm sẵn trong /me/applications từ lâu và web đã hiện nó;
/// app thì chưa bao giờ đọc tới. Một sinh viên được chấm 5 sao sau khi làm
/// xong việc sẽ không bao giờ biết, nếu họ chỉ dùng app.
class RatingCard extends StatelessWidget {
  const RatingCard({
    super.key,
    required this.score,
    this.comment,
    this.companyName,
  });

  final int score;
  final String? comment;
  final String? companyName;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Np.s4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Np.rMd),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRow(score: score, size: 17),
              const SizedBox(width: Np.s2),
              Text('$score/5',
                  style: NpType.body.copyWith(
                      color: c.ink, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: Np.s2),
          Text(
            companyName == null || companyName!.isEmpty
                ? 'Đánh giá sau khi hoàn thành công việc'
                : '$companyName đánh giá sau khi bạn hoàn thành công việc',
            style: NpType.meta.copyWith(color: c.muted),
          ),
          if (comment != null && comment!.isNotEmpty) ...[
            const SizedBox(height: Np.s3),
            Text('“${comment!}”',
                style: NpType.body.copyWith(
                    color: c.ink, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
