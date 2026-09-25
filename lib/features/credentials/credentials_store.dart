import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../profile/gamification_store.dart';
import '../profile/me_store.dart';
import 'credential.dart';

class CredentialsStore extends ChangeNotifier {
  CredentialsStore._();
  static final instance = CredentialsStore._();

  final _api = ApiClient();

  List<Credential> items = const [];
  bool loaded = false;

  int get pendingCount =>
      items.where((e) => e.status == 'PENDING').length;

  /// Lỗi của lần nạp gần nhất, null nếu không có.
  ///
  /// Trước đây lỗi bị nuốt và `loaded` giữ nguyên false, nên màn hình kẹt ở
  /// "Đang tải…" VĨNH VIỄN — không báo lỗi, không có đường thử lại. Người
  /// dùng chỉ biết ngồi nhìn.
  String? error;

  Future<void> hydrate() async {
    try {
      final d = await _api.get('/credentials');
      if (d is! List) return;
      items = d
          .whereType<Map<String, dynamic>>()
          .map(Credential.fromJson)
          .toList();
      error = null;
      loaded = true;
      notifyListeners();
    } on ApiException catch (e) {
      error = e.message;
      loaded = true;
      notifyListeners();
    }
  }

  /// Nộp một minh chứng mới. Trả null khi thành công, chuỗi lỗi khi hỏng.
  Future<String?> submit({
    required String projectName,
    required String position,
    required String category,
    required String roleLevel,
    String? description,
    String? proofLink,
    List<String> proofImages = const [],
    String? startedAt,
    String? endedAt,
  }) async {
    try {
      await _api.post('/credentials', body: {
        'projectName': projectName,
        'position': position,
        'category': category,
        'roleLevel': roleLevel,
        // Bỏ hẳn khoá khi rỗng thay vì gửi chuỗi trống: cột ngày là kiểu
        // `date`, và Postgres từ chối chuỗi rỗng chứ không coi đó là null.
        if (description != null && description.isNotEmpty)
          'description': description,
        if (proofLink != null && proofLink.isNotEmpty) 'proofLink': proofLink,
        if (proofImages.isNotEmpty) 'proofImages': proofImages,
        if (startedAt != null && startedAt.isNotEmpty) 'startedAt': startedAt,
        if (endedAt != null && endedAt.isNotEmpty) 'endedAt': endedAt,
      });

      await hydrate();

      // Nhiệm vụ tuần "Có 1 minh chứng được duyệt" đếm theo sự kiện
      // SUBMIT_PROOF. Ghi ngay lúc NỘP chứ không đợi admin duyệt — đó là
      // cách backend định nghĩa sự kiện này (xem QuestDef trong
      // GamificationService), và người dùng không kiểm soát được khi nào
      // admin xử lý.
      await GamificationStore.instance.record(GameEvent.submitProof);

      // Hồ sơ đếm số kinh nghiệm từ /profiles/me, nên phải nạp lại để tab Hồ
      // sơ không hiện con số cũ.
      await MeStore.instance.hydrate();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void clear() {
    items = const [];
    loaded = false;
    notifyListeners();
  }
}
