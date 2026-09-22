
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../profile/me_store.dart';
import 'applied_store.dart';
import 'eligibility.dart';
import 'opportunity.dart';
import 'opportunity_labels.dart';
import 'save_button.dart';

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
  const OpportunityCard({
    super.key,
    required this.item,
    this.onTap,
    this.isGuest = false,
    this.onNeedSignIn,
  });

  final Opportunity item;
  final VoidCallback? onTap;
  final bool isGuest;
  final VoidCallback? onNeedSignIn;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final posted = relativeTime(item.createdAt);
    final isQuest = item.kind == OpportunityKind.quest;
    final hasPay = item.compensation != null && item.compensation! > 0;


    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Np.s5),
        decoration: Np.card(c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CompanyLogo(url: item.companyLogo, name: item.companyName),
                const SizedBox(width: Np.s3),
                Expanded(
                  child: Text(
                    item.companyName,
                    style: NpType.meta.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _BadgeSlot(item: item, isGuest: isGuest),
                if (isQuest) const MetaChip(label: 'Quest', accent: true),
                // Lùi lề để vùng chạm rộng của nút tim không đội thẻ ra.
                Transform.translate(
                  offset: const Offset(Np.s3, -Np.s2),
                  child: SaveButton(
                    item: item,
                    isGuest: isGuest,
                    onNeedSignIn: onNeedSignIn,
                    size: 20,
                  ),
                ),
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
                    color: hasPay ? c.acidText : c.muted,
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
              Divider(color: c.line, height: 1),
              const SizedBox(height: Np.s3),
              Text(posted,
                  style: NpType.meta.copyWith(fontSize: 12, color: c.faint)),
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


/// Chỗ đặt nhãn chặn, tự vẽ lại khi hồ sơ hoặc danh sách đơn đã nộp thay đổi.
///
/// Phải nghe hai kho đó: cả hai đều nạp BẤT ĐỒNG BỘ sau khi danh sách đã dựng
/// xong. Không nghe thì lần cuộn đầu tiên mọi thẻ đều trông như nộp được, và
/// nhãn chỉ hiện ra khi người dùng tình cờ làm danh sách dựng lại.
class _BadgeSlot extends StatelessWidget {
  const _BadgeSlot({required this.item, required this.isGuest});
  final Opportunity item;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MeStore.instance,
        AppliedStore.instance,
      ]),
      builder: (_, _) {
        // Nhãn chặn hiện NGAY trên thẻ. Để dành tới màn chi tiết mới nói thì
        // người dùng đã mở tin, đọc mô tả và bấm ứng tuyển rồi — mất công cho
        // cả hai bên. Tin vẫn hiện đầy đủ chứ không bị lọc đi: người ta cần
        // thấy mình đang hướng tới cái gì, không phải một danh sách bị cắt ngầm.
        final badge = eligibilityOf(item, isGuest: isGuest).badge;
        if (badge == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: Np.s2),
          child: _Badge(label: badge),
        );
      },
    );
  }
}

/// Nhãn "không nộp được" trên thẻ.
///
/// Trung tính chứ không đỏ: đây không phải lỗi của người dùng, và tô đỏ ba
/// bốn thẻ trong một danh sách sẽ làm cả trang trông như đang báo hỏng.
class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Np.s2 + 2, vertical: 3),
      decoration: BoxDecoration(
        color: c.surfaceHi,
        borderRadius: BorderRadius.circular(Np.rPill),
        border: Border.all(color: c.line),
      ),
      child: Text(label,
          style: NpType.meta.copyWith(
            fontSize: 11.5,
            color: c.muted,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}
