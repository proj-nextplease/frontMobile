import '../profile/me_store.dart';
import 'applied_store.dart';
import 'opportunity.dart';

/// Vì sao người dùng chưa nộp đơn được.
///
/// ─── Vì sao lớp này tồn tại ──────────────────────────────────────────────
/// Backend chặn theo đúng thứ tự: OPEN → hết hạn → điểm uy tín → Premium →
/// trùng đơn (xem ApplicationService.apply). Nhưng mọi lời chặn đó chỉ đến
/// SAU KHI người dùng đã mở tin, bấm Ứng tuyển, gõ lời nhắn và bấm gửi. Bắt
/// người ta làm xong việc rồi mới nói "bạn không đủ điều kiện" là cách chắc
/// chắn làm họ bực.
///
/// App đã biết trước gần hết: hạn nộp nằm trong tin, điểm uy tín nằm trong
/// hồ sơ, danh sách đơn đã nộp có endpoint riêng. Nên tính ở client và nói
/// TRƯỚC. Máy chủ vẫn là nơi quyết định cuối cùng — đây là lớp báo trước, KHÔNG
/// phải lớp bảo mật.
enum Blocker {
  /// Nộp được.
  none,

  /// Chưa đăng nhập. Không phải "không đủ điều kiện" — chỉ là chưa biết.
  guest,

  /// Đã quá hạn nộp.
  expired,

  /// Điểm uy tín chưa đủ.
  reputation,

  /// Đã nộp đơn cho cơ hội này rồi.
  applied,
}

class Eligibility {
  const Eligibility(this.blocker, {this.needRs = 0, this.myRs = 0});

  final Blocker blocker;
  final int needRs;
  final int myRs;

  bool get canApply => blocker == Blocker.none;

  /// Thiếu bao nhiêu điểm nữa. Con số này là thứ có ích, không phải "bạn chưa
  /// đủ điều kiện" chung chung.
  int get shortBy => (needRs - myRs).clamp(0, needRs);

  /// Nhãn ngắn để in lên thẻ trong danh sách.
  String? get badge => switch (blocker) {
        Blocker.expired => 'Hết hạn',
        Blocker.reputation => 'Cần $needRs RS',
        Blocker.applied => 'Đã nộp',
        _ => null,
      };

  /// Câu giải thích đầy đủ cho màn chi tiết.
  String? get reason => switch (blocker) {
        Blocker.expired => 'Cơ hội này đã hết hạn nhận đơn.',
        Blocker.reputation =>
          'Cần $needRs điểm uy tín, bạn đang có $myRs. Còn thiếu $shortBy điểm — '
              'hoàn thành quest để tăng điểm.',
        Blocker.applied => 'Bạn đã nộp đơn cho cơ hội này.',
        _ => null,
      };
}

/// Xét điều kiện nộp đơn.
///
/// KHÔNG xét gói Premium. Máy chủ kiểm tra `premium_until > now()`, còn app
/// chỉ thấy vai trò `candidate_premium` — vai trò không tự mất khi gói hết
/// hạn, nên dựa vào nó sẽ chặn nhầm người đang còn hạn hoặc thả nhầm người đã
/// hết. Yêu cầu Premium vẫn được HIỆN ra như một thông tin của tin, chỉ là
/// không dùng để khoá nút.
Eligibility eligibilityOf(Opportunity o, {required bool isGuest}) {
  final d = o.deadlineAt ?? o.endsAt;
  if (d != null && d.isBefore(DateTime.now())) {
    // Hết hạn tính trước cả việc đăng nhập: tin đã đóng thì đăng nhập cũng
    // không mở ra được, mời họ đăng nhập lúc này là mời hụt.
    return const Eligibility(Blocker.expired);
  }

  if (isGuest) return const Eligibility(Blocker.guest);

  if (AppliedStore.instance.hasApplied(o)) {
    return const Eligibility(Blocker.applied);
  }

  final me = MeStore.instance;
  // Hồ sơ chưa nạp xong thì KHÔNG đoán. Mặc định cho nộp và để máy chủ trả
  // lời — chặn nhầm một người đủ điều kiện tệ hơn là để lọt một lời chặn
  // muộn.
  if (me.loaded && o.minReqRs > me.reputationScore) {
    return Eligibility(Blocker.reputation,
        needRs: o.minReqRs, myRs: me.reputationScore);
  }

  return const Eligibility(Blocker.none);
}
