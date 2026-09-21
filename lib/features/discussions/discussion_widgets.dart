import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../jobs/opportunity_labels.dart';
import 'discussion_models.dart';

/// Ảnh đại diện. Không có ảnh thì lấy chữ cái đầu — KHÔNG dùng ảnh mặc định
/// hình người: một dãy avatar giống hệt nhau làm cả feed trông như bot.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 38});
  final String name;
  final String? url;
  final double size;

  /// Màu nền suy ra từ tên, nên mỗi người có một màu ổn định qua các lần mở.
  /// Dải màu cố ý nhạt và lệch tông nhau chứ không dùng màu thương hiệu —
  /// màu thương hiệu dành cho hành động, không dành cho trang trí.
  static const _tints = [
    Color(0xFF7C6CF0), Color(0xFFE0698A), Color(0xFF3AA6B9),
    Color(0xFFE08B3A), Color(0xFF5E9E4A), Color(0xFF9B5FC0),
  ];

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final tint = _tints[name.hashCode.abs() % _tints.length];

    if (url != null) {
      return ClipOval(
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _letter(letter, tint, c),
        ),
      );
    }
    return _letter(letter, tint, c);
  }

  Widget _letter(String letter, Color tint, NpColors c) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Text(letter,
            style: NpType.title.copyWith(
              fontSize: size * 0.42,
              color: tint,
            )),
      );
}

/// Khối bình chọn.
class PollBox extends StatelessWidget {
  const PollBox({super.key, required this.poll, required this.onVote});
  final DiscussionPoll poll;
  final ValueChanged<String>? onVote;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final o in poll.options) ...[
          GestureDetector(
            onTap: poll.hasVoted || onVote == null ? null : () => onVote!(o.id),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(bottom: Np.s2),
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Np.rSm),
                border: Border.all(
                  color: o.id == poll.votedOptionId ? c.acid : c.line,
                ),
              ),
              child: Stack(
                children: [
                  // Thanh tỉ lệ CHỈ vẽ sau khi đã bỏ phiếu. Hiện trước thì
                  // người đọc thấy phương án nào đang thắng rồi mới chọn, và
                  // kết quả khảo sát thành vô nghĩa.
                  if (poll.hasVoted)
                    FractionallySizedBox(
                      widthFactor: o.share(poll.totalVotes),
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.acid.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(Np.rSm),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Np.s3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(o.text,
                              style: NpType.meta.copyWith(
                                fontSize: 13.5,
                                color: c.ink,
                                fontWeight: o.id == poll.votedOptionId
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (poll.hasVoted)
                          Text(
                            '${(o.share(poll.totalVotes) * 100).round()}%',
                            style: NpType.meta.copyWith(
                                fontSize: 12.5, color: c.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        Text(
          poll.totalVotes == 0
              ? 'Chưa có lượt bình chọn'
              : '${poll.totalVotes} lượt bình chọn',
          style: NpType.meta.copyWith(fontSize: 11.5, color: c.faint),
        ),
      ],
    );
  }
}

/// Một hành động dưới bài: biểu tượng + số.
class PostAction extends StatelessWidget {
  const PostAction({
    super.key,
    required this.icon,
    required this.count,
    this.active = false,
    this.onTap,
  });

  final NpIcon icon;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final color = active ? c.acidText : c.muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Vùng chạm rộng hơn phần nhìn thấy: biểu tượng 17px mà không có đệm
        // thì bấm trượt liên tục trên điện thoại.
        padding: const EdgeInsets.symmetric(vertical: Np.s2, horizontal: Np.s1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NpIco(icon, size: 17, color: color),
            if (count > 0) ...[
              const SizedBox(width: Np.s1 + 2),
              Text('$count',
                  style: NpType.meta.copyWith(fontSize: 12.5, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dòng tác giả: tên, vai trò, thời gian, chủ đề.
class AuthorLine extends StatelessWidget {
  const AuthorLine({super.key, required this.post});
  final DiscussionPost post;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(post.authorName,
              style: NpType.body.copyWith(
                fontSize: 14.5,
                color: c.ink,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        if (post.createdAt != null) ...[
          const SizedBox(width: Np.s2),
          Text('· ${relativeTime(post.createdAt)}',
              style: NpType.meta.copyWith(fontSize: 12, color: c.faint)),
        ],
      ],
    );
  }
}
