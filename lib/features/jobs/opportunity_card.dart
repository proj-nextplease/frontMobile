import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'opportunity.dart';
import 'opportunity_labels.dart';

/// Thẻ một cơ hội.
///
/// Thứ tự đọc được dựng có chủ ý, từ trên xuống:
///   logo + tên tổ chức   → "ai đăng"
///   TIÊU ĐỀ cỡ lớn       → "việc gì"
///   LƯƠNG cỡ lớn, acid   → "được bao nhiêu"
///   chip                 → "ở đâu, dạng gì"
///
/// Bốn bản trước đặt tiêu đề và tên tổ chức sát nhau cùng cỡ, nên mắt phải
/// đọc mới phân biệt được. Ở đây tên tổ chức nằm TRÊN, nhỏ và mờ, còn tiêu đề
/// đứng riêng một khối — quét mắt là ra ngay.
///
/// Lương là thông tin duy nhất được tô acid. Đó là con số người dùng tìm đầu
/// tiên, và cho nó độc quyền màu nhấn đáng giá hơn rải màu khắp thẻ.
class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.item, this.onTap});

  final Opportunity item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final posted = relativeTime(item.createdAt);
    final isQuest = item.kind == OpportunityKind.quest;
    final hasPay = item.compensation != null && item.compensation! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Np.s5),
        decoration: Np.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Logo(url: item.companyLogo, name: item.companyName),
                const SizedBox(width: Np.s3),
                Expanded(
                  child: Text(
                    item.companyName,
                    style: NpType.meta.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isQuest)
                  const MetaChip(label: 'Quest', tone: Np.acid),
              ],
            ),
            const SizedBox(height: Np.s4),

            Text(
              item.title,
              style: NpType.title.copyWith(fontSize: 18, height: 1.28),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Np.s3),

            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  salaryLabel(
                    compensation: item.compensation,
                    isQuest: isQuest,
                  ),
                  style: NpType.title.copyWith(
                    fontSize: hasPay ? 19 : 15,
                    fontWeight: FontWeight.w700,
                    color: hasPay ? Np.acid : Np.muted,
                    letterSpacing: -0.4,
                  ),
                ),
                if (item.expReward != null) ...[
                  const SizedBox(width: Np.s2),
                  Text('· +${item.expReward} EXP', style: NpType.meta),
                ],
              ],
            ),
            const SizedBox(height: Np.s4),

            Wrap(
              spacing: Np.s2,
              runSpacing: Np.s2,
              children: [
                MetaChip(
                  icon: Icons.place_outlined,
                  label: item.isRemote
                      ? '${item.location ?? "Không rõ"} · Remote'
                      : (item.location ?? 'Không rõ'),
                ),
                MetaChip(
                  icon: Icons.schedule_rounded,
                  label: typeLabel(item.typeCode),
                ),
              ],
            ),

            if (posted.isNotEmpty) ...[
              const SizedBox(height: Np.s4),
              const Divider(color: Np.line, height: 1),
              const SizedBox(height: Np.s3),
              Text(posted,
                  style: NpType.meta.copyWith(fontSize: 12, color: Np.faint)),
            ],
          ],
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
    const size = 26.0;
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? 'NP'
        : trimmed.substring(0, trimmed.length.clamp(1, 2)).toUpperCase();

    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Np.surfaceHi,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Np.line),
          ),
          child: Text(
            initials,
            style: NpType.label.copyWith(
              fontSize: 9.5,
              color: Np.muted,
              letterSpacing: 0,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: image,
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
