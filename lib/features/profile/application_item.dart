import '../../core/theme.dart';
import 'package:flutter/material.dart';

/// Một đơn đã nộp — gộp chung đơn tin tuyển dụng và đơn quest.
///
/// CẢNH BÁO khi sửa: hai endpoint trả về hai KIỂU ĐẶT TÊN khác nhau.
///   GET /me/applications        → job_title, company_name, applied_at  (snake)
///   GET /me/quest-applications  → questTitle, companyName, appliedAt   (camel)
/// Đây là điều đã kiểm chứng trong ApplicationService và QuestService, không
/// phải phỏng đoán. Đọc một kiểu thôi thì một nửa số đơn hiện ra trống trơn mà
/// không báo lỗi gì.
class ApplicationItem {
  const ApplicationItem({
    required this.id,
    required this.title,
    required this.companyName,
    required this.status,
    required this.isQuest,
    this.appliedAt,
    this.rejectReason,
  });

  final String id;
  final String title;
  final String companyName;
  final String status;
  final bool isQuest;
  final DateTime? appliedAt;
  final String? rejectReason;

  factory ApplicationItem.fromJob(Map<String, dynamic> m) => ApplicationItem(
        id: '${m['id']}',
        title: _str(m['job_title']) ?? 'Tin tuyển dụng',
        companyName: _str(m['company_name']) ?? '',
        status: '${m['status'] ?? ''}'.toUpperCase(),
        isQuest: false,
        appliedAt: _date(m['applied_at']),
        rejectReason: _str(m['reject_reason']),
      );

  factory ApplicationItem.fromQuest(Map<String, dynamic> m) => ApplicationItem(
        id: '${m['id']}',
        title: _str(m['questTitle']) ?? 'Quest',
        companyName: _str(m['companyName']) ?? '',
        status: '${m['status'] ?? ''}'.toUpperCase(),
        isQuest: true,
        appliedAt: _date(m['appliedAt']),
        rejectReason: _str(m['rejectReason']),
      );

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
}

/// Các trạng thái CÒN ĐANG CHỜ, tức là chưa có kết luận.
///
/// Giá trị lấy từ ràng buộc ck_applications_status (migration V19):
/// SUBMITTED, VIEWED, SHORTLISTED, ACCEPTED, REJECTED, WITHDRAWN, COMPLETED.
/// KHÔNG có 'PENDING' — mọi chỗ lọc theo chuỗi đó sẽ luôn đếm ra 0.
const kOpenStatuses = {'SUBMITTED', 'VIEWED', 'SHORTLISTED'};

String applicationStatusLabel(String s) => switch (s) {
      'SUBMITTED' => 'Đã nộp',
      'VIEWED' => 'Đã xem',
      'SHORTLISTED' => 'Vào vòng trong',
      'ACCEPTED' => 'Được nhận',
      'REJECTED' => 'Từ chối',
      'WITHDRAWN' => 'Đã rút',
      'COMPLETED' => 'Hoàn thành',
      _ => s.isEmpty ? 'Không rõ' : s,
    };

/// Màu của nhãn trạng thái.
///
/// Chỉ ba mức: tốt (xanh), xấu (đỏ), còn lại trung tính. Tô mỗi trạng thái
/// một màu riêng sẽ biến danh sách thành bảng cầu vồng và không mức nào nổi.
Color applicationStatusColor(String s, NpColors c) => switch (s) {
      'ACCEPTED' || 'COMPLETED' => c.acidText,
      'REJECTED' => c.danger,
      _ => c.muted,
    };
