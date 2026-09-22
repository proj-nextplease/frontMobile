// Bảng nhiệm vụ trên trang chủ và tab Hồ sơ.
//
// Kiểm ở đây vì để thấy khoảnh khắc nhận thưởng trên máy ảo thì phải có sẵn
// một nhiệm vụ vừa hoàn thành mà chưa nhận — trạng thái chỉ xuất hiện đúng
// một lần mỗi ngày và không dựng lại được bằng tay.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/core/theme.dart';
import 'package:nextplease_mobile/features/profile/gamification_store.dart';
import 'package:nextplease_mobile/features/profile/quest_board.dart';

Map<String, Object?> _state({required bool completed, bool claimed = false}) => {
      'level': 1,
      'expIntoLevel': 20,
      'expForNextLevel': 100,
      'currentStreak': 2,
      'dailyQuests': [
        {
          'key': 'DAILY_LOGIN',
          'scope': 'DAILY',
          'title': 'Ghé thăm mỗi ngày',
          'desc': '',
          'progress': completed ? 1 : 0,
          'target': 1,
          'exp': 20,
          'completed': completed,
          'claimed': claimed,
        }
      ],
      'weeklyQuests': [
        {
          'key': 'WEEKLY_APPLY',
          'scope': 'WEEKLY',
          'title': 'Ứng tuyển 3 cơ hội',
          'desc': '',
          'progress': 0,
          'target': 3,
          'exp': 150,
          'completed': false,
          'claimed': false,
        }
      ],
    };

Widget _board() => MaterialApp(
      theme: buildNpTheme(Brightness.light),
      home: Scaffold(
        body: QuestBoard(store: GamificationStore.instance),
      ),
    );

void main() {
  final store = GamificationStore.instance;
  tearDown(store.clear);

  testWidgets('Mỗi dòng ghi rõ phạm vi ngày hay tuần', (tester) async {
    store.debugApply(_state(completed: false));
    await tester.pumpWidget(_board());
    await tester.pump();

    // Tiêu đề chung không thể nói đúng cho cả hai, nên phạm vi phải nằm trên
    // từng dòng.
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Tuần'), findsOneWidget);
  });

  testWidgets('Chưa hoàn thành thì không có nút Nhận', (tester) async {
    store.debugApply(_state(completed: false));
    await tester.pumpWidget(_board());
    await tester.pump();

    expect(find.text('Nhận'), findsNothing);
  });

  testWidgets('Hoàn thành rồi thì hiện nút Nhận', (tester) async {
    store.debugApply(_state(completed: true));
    await tester.pumpWidget(_board());
    await tester.pump();

    expect(find.text('Nhận'), findsOneWidget);
  });

  testWidgets('Nhiệm vụ đã nhận thưởng thì biến khỏi danh sách',
      (tester) async {
    store.debugApply(_state(completed: true, claimed: true));
    await tester.pumpWidget(_board());
    await tester.pump();

    expect(find.text('Ghé thăm mỗi ngày'), findsNothing);
    // Nhiệm vụ còn dở vẫn ở lại.
    expect(find.text('Ứng tuyển 3 cơ hội'), findsOneWidget);
  });
}
