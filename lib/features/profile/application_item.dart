import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

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
    this.coverNote,
    this.history = const [],
  });

  final String id;
  final String title;
  final String companyName;
  final String status;
  final bool isQuest;
  final DateTime? appliedAt;
  final String? rejectReason;
  final String? coverNote;

  /// Các mốc trạng thái, cũ trước mới sau.
  final List<StatusStep> history;

  /// Rút đơn được khi nào. Danh sách trạng thái CẤM lấy từ
  /// ApplicationService.withdrawApplication: WITHDRAWN, ACCEPTED, COMPLETED,
  /// REJECTED. Kiểm ở đây để nút rút không hiện ra rồi mới báo lỗi 409 —
  /// đúng cùng một lỗi trải nghiệm với rào ứng tuyển.
  bool get canWithdraw => kOpenStatuses.contains(status);

  String get withdrawPath => isQuest
      ? '/me/quest-applications/$id/withdraw'
      : '/me/applications/$id/withdraw';

  factory ApplicationItem.fromJob(Map<String, dynamic> m) => ApplicationItem(
        id: '${m['id']}',
        title: _str(m['job_title']) ?? 'Tin tuyển dụng',
        companyName: _str(m['company_name']) ?? '',
        status: '${m['status'] ?? ''}'.toUpperCase(),
        isQuest: false,
        appliedAt: _date(m['applied_at']),
        rejectReason: _str(m['reject_reason']),
        coverNote: _str(m['cover_note']),
        history: _history(m['statusHistory']),
      );

  factory ApplicationItem.fromQuest(Map<String, dynamic> m) => ApplicationItem(
        id: '${m['id']}',
        title: _str(m['questTitle']) ?? 'Quest',
        companyName: _str(m['companyName']) ?? '',
        status: '${m['status'] ?? ''}'.toUpperCase(),
        isQuest: true,
        appliedAt: _date(m['appliedAt']),
        rejectReason: _str(m['rejectReason']),
        coverNote: _str(m['cover_note'] ?? m['coverNote']),
        history: _history(m['statusHistory']),
      );

  /// Bản sao với trạng thái mới, kèm một mốc mới vào cuối dòng thời gian.
  ApplicationItem withStatus(String next) => ApplicationItem(
        id: id,
        title: title,
        companyName: companyName,
        status: next,
        isQuest: isQuest,
        appliedAt: appliedAt,
        rejectReason: rejectReason,
        coverNote: coverNote,
        history: [...history, StatusStep(status: next, at: DateTime.now())],
      );

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  /// `statusHistory` về dưới dạng CHUỖI JSON, không phải mảng.
  ///
  /// Cả hai service đều ép kiểu `jsonb_agg(...)::text` trước khi trả, nên đọc
  /// thẳng như một List sẽ luôn ra rỗng mà không ném lỗi — mốc trạng thái đơn
  /// giản là không bao giờ hiện.
  static List<StatusStep> _history(Object? v) {
    if (v is! String || v.isEmpty) return const [];
    try {
      final raw = jsonDecode(v);
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => StatusStep(
                status: '${m['status'] ?? ''}'.toUpperCase(),
                at: _date(m['at']),
              ))
          .where((e) => e.status.isNotEmpty)
          .toList();
    } on FormatException {
      return const [];
    }
  }
}

/// Một mốc trong hành trình của đơn.
class StatusStep {
  const StatusStep({required this.status, this.at});
  final String status;
  final DateTime? at;
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
