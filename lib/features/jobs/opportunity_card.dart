import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'opportunity.dart';
import 'opportunity_labels.dart';

/// Thẻ một cơ hội — hệ giấy/sticker.
///
/// Một quyết định đi ngược bản năng: thẻ ở đây KHÔNG có bóng đổ cứng, chỉ có
/// viền 2px. DESIGN.md nói rõ "bóng đổ cứng chỉ cho các tấm lớn; gắn cho từng
/// ô thì 30 cái bóng chồng xuống một cột". Danh sách này có 10–14 thẻ, đủ để
/// biến thành một cột bóng lởm chởm và làm mắt không bám được nội dung.
///
/// Bóng cứng vẫn giữ cho những thứ ĐƠN LẺ trên màn hình: chip lọc đang chọn,
/// nhãn Quest, nút. Đó là cách "loud ở vỏ, calm ở ruột" áp vào một danh sách.
class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.item, this.onTap});

  final Opportunity item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final posted = relativeTime(item.createdAt);
    final isQuest = item.kind == OpportunityKind.quest;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Paper.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Paper.ink, width: Paper.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Logo(url: item.companyLogo, name: item.companyName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: t.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.companyName,
                        style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isQuest) const _QuestTag(),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _Chip(
                  label: salaryLabel(
                    compensation: item.compensation,
                    isQuest: isQuest,
                  ),
                  // Tiền là thứ ứng viên quét mắt tìm đầu tiên — cho nó nền lime.
                  fill: item.compensation != null ? Paper.lime : null,
                ),
                _Chip(
                  label: item.isRemote
                      ? '${item.location ?? "Không rõ"} · Remote'
                      : (item.location ?? 'Không rõ'),
                ),
                _Chip(label: typeLabel(item.typeCode)),
                if (item.expReward != null)
                  _Chip(label: '+${item.expReward} EXP', fill: Paper.violet, onDark: true),
              ],
            ),
            if (posted.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                posted,
                style: t.bodySmall?.copyWith(fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestTag extends StatelessWidget {
  const _QuestTag();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: Paper.card(fill: Paper.coral, radius: 999, dx: 2, dy: 2),
        child: const Text(
          'QUEST',
          style: TextStyle(
            color: Paper.bg,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            height: kViUppercaseLineHeight,
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.fill, this.onDark = false});
  final String label;
  final Color? fill;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fill ?? Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Paper.ink, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.8,
            fontWeight: FontWeight.w700,
            color: onDark ? Paper.bg : Paper.ink,
          ),
        ),
      );
}

/// Logo tổ chức, có phương án dự phòng.
///
/// Logo lưu dưới dạng data URL base64 trong companies.logo_url. Image.network
/// KHÔNG đọc được lược đồ `data:` — nó chỉ làm việc với http/https — nên phải
/// tự giải mã rồi dựng bằng Image.memory. Bỏ qua chỗ này thì mọi logo đều
/// thất bại IM LẶNG và rơi về chữ cái đầu.
class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    const size = 46.0;
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? 'NP'
        : trimmed.substring(0, trimmed.length.clamp(1, 2)).toUpperCase();

    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Paper.violet,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Paper.ink, width: 1.5),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: Paper.bg,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        );

    final src = url;
    if (src == null || src.isEmpty) return fallback();

    final Widget image;
    if (src.startsWith('data:')) {
      final comma = src.indexOf(',');
      final bytes = comma == -1 ? null : _tryDecode(src.substring(comma + 1));
      if (bytes == null) return fallback();
      image = Image.memory(bytes,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback());
    } else {
      image = Image.network(src,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback());
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Paper.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Paper.ink, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: image,
      ),
    );
  }
}

/// Giải mã base64; chuỗi hỏng thì trả null để nơi gọi dùng phương án dự phòng
/// thay vì ném lỗi ra giữa lúc dựng giao diện.
Uint8List? _tryDecode(String b64) {
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}
