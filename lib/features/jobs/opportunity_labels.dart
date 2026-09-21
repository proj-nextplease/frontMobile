/// Nhãn tiếng Việt cho mã loại cơ hội.
///
/// Gộp cả job_type lẫn quest category vào một bảng vì sau khi trộn danh sách
/// thì nơi hiển thị không cần biết mã đến từ bảng nào.
/// Giá trị hợp lệ lấy từ ràng buộc ck_jobs_type và ck_quests_category trong
/// migration V2 của backend — thiếu mã nào thì thẻ hiện nguyên chuỗi hoa.
const kTypeLabels = <String, String>{
  // jobs
  'INTERNSHIP': 'Thực tập sinh',
  'PART_TIME': 'Bán thời gian',
  'FREELANCE': 'Freelance',
  'EVENT_STAFF': 'Event Staff',
  'MICRO_INTERNSHIP': 'Thực tập ngắn hạn',
  // quests
  'SMALL_EVENT': 'Sự kiện CLB',
  'SCHOOL_CAMPAIGN': 'Chiến dịch trường',
  'COMPANY_PROJECT': 'Dự án doanh nghiệp',
  'SHORT_INTERNSHIP': 'Thực tập ngắn hạn',
  'FREELANCE_GIG': 'Việc tự do ngắn',
};

String typeLabel(String? code) =>
    code == null ? 'Khác' : (kTypeLabels[code] ?? code);

/// Lương hiển thị. Không có số thì KHÔNG bịa "thoả thuận" — nói rõ là không
/// công khai, còn quest thì bản chất không trả lương.
String salaryLabel({num? compensation, required bool isQuest}) {
  if (compensation == null || compensation <= 0) {
    return isQuest ? 'Hỗ trợ & Proof' : 'Lương không công khai';
  }
  final trieu = compensation / 1000000;
  if (trieu >= 1) {
    final s = trieu.toStringAsFixed(trieu.truncateToDouble() == trieu ? 0 : 1);
    return '$s triệu';
  }
  return '${compensation.toStringAsFixed(0)} đ';
}

String relativeTime(DateTime? d) {
  if (d == null) return '';   // thiếu dữ liệu thì để trống, không đoán
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'Đăng ${diff.inMinutes.clamp(1, 59)} phút trước';
  if (diff.inHours < 24) return 'Đăng ${diff.inHours} giờ trước';
  if (diff.inDays < 30) return 'Đăng ${diff.inDays} ngày trước';
  return 'Đăng ${(diff.inDays / 30).round()} tháng trước';
}
