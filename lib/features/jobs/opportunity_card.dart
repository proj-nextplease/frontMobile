import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'opportunity.dart';
import 'opportunity_labels.dart';

/// Thẻ một cơ hội. Theo DESIGN.md: nền ink-soft, viền 1px line-dark, bo 16px,
/// KHÔNG dùng box-shadow.
class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.item, this.onTap});

  final Opportunity item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final posted = relativeTime(item.createdAt);

    return Material(
      color: NpColors.inkSoft,
      borderRadius: BorderRadius.circular(NpRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NpRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(NpSpace.cardPad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NpRadius.lg),
            border: Border.all(color: NpColors.lineDark),
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
                        const SizedBox(height: 2),
                        Text(
                          item.companyName,
                          style: t.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (item.kind == OpportunityKind.quest) const _QuestTag(),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: Icons.payments_outlined,
                    label: salaryLabel(
                      compensation: item.compensation,
                      isQuest: item.kind == OpportunityKind.quest,
                    ),
                  ),
                  _Chip(
                    icon: Icons.place_outlined,
                    label: item.isRemote
                        ? '${item.location ?? "Không xác định"} (Remote)'
                        : (item.location ?? 'Không xác định'),
                  ),
                  _Chip(icon: Icons.work_outline, label: typeLabel(item.typeCode)),
                  if (item.expReward != null)
                    _Chip(icon: Icons.bolt_outlined, label: '+${item.expReward} EXP'),
                ],
              ),
              if (posted.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(posted, style: t.bodySmall),
              ],
            ],
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: NpColors.emerald.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(NpRadius.pill),
          border: Border.all(color: NpColors.emerald.withValues(alpha: 0.45)),
        ),
        child: const Text(
          'Quest',
          style: TextStyle(
            color: NpColors.emeraldHover,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NpRadius.pill),
          border: Border.all(color: NpColors.lineDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: NpColors.mutedDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: NpColors.mutedDark),
            ),
          ],
        ),
      );
}

/// Logo tổ chức, có phương án dự phòng.
///
/// Logo lưu dưới dạng data URL base64 trong DB nên link hỏng là chuyện thường.
/// errorBuilder bắt trường hợp đó và rơi về chữ cái đầu, thay vì để Flutter vẽ
/// ô xám trống.
class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    final initials =
        name.trim().isEmpty ? 'NP' : name.trim().substring(0, name.trim().length.clamp(1, 2)).toUpperCase();

    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NpColors.emerald.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: NpColors.emeraldHover,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        );

    final src = url;
    if (src == null || src.isEmpty) return fallback();

    /* Logo được lưu thành data URL base64 trong companies.logo_url (web chọn
       cách đó vì dự án chưa có endpoint upload tệp). Image.network KHÔNG đọc
       được lược đồ `data:` — nó chỉ làm việc với http/https — nên phải tự giải
       mã rồi dựng bằng Image.memory. Bỏ qua chỗ này thì mọi logo đều rơi về
       chữ cái đầu mà không báo lỗi gì. */
    final Widget image;
    if (src.startsWith('data:')) {
      final comma = src.indexOf(',');
      final bytes = comma == -1 ? null : _tryDecode(src.substring(comma + 1));
      if (bytes == null) return fallback();
      image = Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      image = Image.network(
        src,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    return ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
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
