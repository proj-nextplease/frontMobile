// Banner khi nhiệm vụ vừa hoàn thành.
//
// Kiểm ở đây vì trên máy ảo phải làm đủ ba lần "xem cơ hội" mới thấy một lần
// banner, và lần nạp đầu tiên thì cố ý không bắn gì — hai điều kiện đó khó
// dựng bằng tay mà lại dễ hỏng âm thầm khi sửa.
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/core/app_banner.dart';
import 'package:nextplease_mobile/features/profile/gamification_store.dart';

Map<String, Object?> _state({
  required int progress,
  int target = 3,
}) =>
    {
      'level': 1,
      'expIntoLevel': 0,
      'expForNextLevel': 100,
      'currentStreak': 1,
      'dailyQuests': [
        {
          'key': 'DAILY_VIEW_OPPORTUNITIES',
          'scope': 'DAILY',
          'title': 'Khám phá 3 cơ hội',
          'desc': '',
          'progress': progress,
          'target': target,
          'exp': 30,
          'completed': progress >= target,
          'claimed': false,
        }
      ],
      'weeklyQuests': const [],
    };

void main() {
  final store = GamificationStore.instance;
  tearDown(store.clear);

  test('Lần nạp đầu tiên KHÔNG bắn banner, kể cả khi đã hoàn thành', () async {
    final seen = <AppBanner>[];
    final sub = store.banners.listen(seen.add);

    store.debugApply(_state(progress: 3));
    await Future<void>.delayed(Duration.zero);

    expect(seen, isEmpty,
        reason: 'vừa mở app mà đổ banner cho việc làm từ trước là vô nghĩa');
    await sub.cancel();
  });

  test('Chuyển từ dở dang sang hoàn thành thì bắn đúng một banner', () async {
    store.debugApply(_state(progress: 2));

    final seen = <AppBanner>[];
    final sub = store.banners.listen(seen.add);

    store.debugApply(_state(progress: 3));
    await Future<void>.delayed(Duration.zero);

    expect(seen.length, 1);
    expect(seen.single.title, contains('Khám phá 3 cơ hội'));
    // Phải nói rõ còn phải BẤM NHẬN, không thì người dùng tưởng đã cộng rồi.
    expect(seen.single.body, contains('Nhận'));
    await sub.cancel();
  });

  test('Đã hoàn thành từ trước thì không bắn lại', () async {
    store.debugApply(_state(progress: 3));

    final seen = <AppBanner>[];
    final sub = store.banners.listen(seen.add);

    store.debugApply(_state(progress: 3));
    await Future<void>.delayed(Duration.zero);

    expect(seen, isEmpty);
    await sub.cancel();
  });
}
