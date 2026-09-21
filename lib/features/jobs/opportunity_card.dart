import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'opportunity.dart';
import 'opportunity_labels.dart';

/// Thẻ một cơ hội.
///
/// Kỷ luật màu: đa số chip là trung tính. Chỉ hai thứ được tô màu, và mỗi màu
/// mang đúng một nghĩa —
///   tím   = quest (loại cơ hội khác)
///   mint  = phần thưởng EXP
/// Lương KHÔNG tô màu dù nó quan trọng nhất; nó nổi bằng chữ đậm và cỡ lớn
/// hơn. Tô màu cho mọi thứ quan trọng là cách nhanh nhất quay lại lỗi "quá
/// nhiều màu" của bản trước.
class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.item, this.onTap});

  final Opportunity item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final posted = relativeTime(item.createdAt);
    final isQuest = item.kind == OpportunityKind.quest;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Np.rLg),
        child: Container(
          padding: const EdgeInsets.all(Np.cardPad),
          decoration: Np.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Logo(url: item.companyLogo, name: item.companyName),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: t.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(item.companyName,
                            style: t.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (isQuest) ...[
                    const SizedBox(width: 8),
                    const SoftChip(label: 'Quest', tone: Np.violet),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      salaryLabel(
                        compensation: item.compensation,
                        isQuest: isQuest,
                      ),
                      style: t.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: item.compensation != null ? Np.ink : Np.muted,
                      ),
                    ),
                  ),
                  if (item.expReward != null)
                    SoftChip(label: '+${item.expReward} EXP', tone: Np.mint),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  SoftChip(
                    icon: Icons.place_outlined,
                    label: item.isRemote
                        ? '${item.location ?? "Không rõ"} · Remote'
                        : (item.location ?? 'Không rõ'),
                  ),
                  SoftChip(
                    icon: Icons.work_outline_rounded,
                    label: typeLabel(item.typeCode),
                  ),
                ],
              ),
              if (posted.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(posted, style: t.bodySmall?.copyWith(fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
    const size = 48.0;
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? 'NP'
        : trimmed.substring(0, trimmed.length.clamp(1, 2)).toUpperCase();

    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: Np.brand,
            borderRadius: BorderRadius.circular(Np.rSm + 2),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
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
        color: Np.bg,
        borderRadius: BorderRadius.circular(Np.rSm + 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Np.rSm + 2),
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
