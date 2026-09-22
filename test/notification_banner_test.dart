// Banner nhắc trong app.
//
// Kiểm ở đây chứ không trên máy ảo vì để thấy banner thật thì phải có một
// thông báo MỚI từ máy chủ đúng lúc app đang mở — cần tài khoản thứ hai và
// một hành động của họ. Đường đi từ "có tin mới" tới "banner hiện ra" thì
// kiểm được trọn vẹn ở đây mà không đụng tới dữ liệu thật.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/core/theme.dart';
import 'package:nextplease_mobile/features/profile/notification_banner.dart';
import 'package:nextplease_mobile/features/profile/notifications_store.dart';

/// Dựng đúng cách app thật dùng: host nằm ở MaterialApp.builder, tức là TRÊN
/// Navigator. Dựng bằng `home:` thì test sẽ xanh trong khi app thật hỏng —
/// đúng lỗi đã xảy ra.
Widget _host({GlobalKey<NavigatorState>? navKey}) => MaterialApp(
      theme: buildNpTheme(Brightness.light),
      navigatorKey: navKey,
      builder: (context, child) => NotificationBannerHost(
        navigatorKey: navKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Center(child: Text('nội dung'))),
    );

void main() {
  tearDown(NotificationsStore.instance.clear);

  testWidgets('Không có tin mới thì không có banner', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('nội dung'), findsOneWidget);
    expect(find.text('Hồ sơ của bạn đã được xem'), findsNothing);
  });

  testWidgets('Có tin mới thì banner hiện rồi tự tắt', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    NotificationsStore.instance.debugEmit(const NotificationItem(
      id: 'n1',
      title: 'Hồ sơ của bạn đã được xem',
      body: 'Nhà tuyển dụng vừa xem đơn ứng tuyển của bạn.',
      isRead: false,
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hồ sơ của bạn đã được xem'), findsOneWidget);

    // Tự tắt sau 5 giây. Nếu mốc này đổi mà quên sửa ở đây thì test sập —
    // đúng như mong muốn, vì một banner không bao giờ tắt là lỗi nặng hơn.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hồ sơ của bạn đã được xem'), findsNothing);
  });

  testWidgets('Tin đến sau ĐÈ tin đang hiện', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    NotificationsStore.instance.debugEmit(const NotificationItem(
        id: 'a', title: 'Tin cũ', body: '', isRead: false));
    await tester.pump(const Duration(milliseconds: 300));

    NotificationsStore.instance.debugEmit(const NotificationItem(
        id: 'b', title: 'Tin mới', body: '', isRead: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tin mới'), findsOneWidget);
    expect(find.text('Tin cũ'), findsNothing);

    // Dọn hẹn giờ đang treo, không thì test kết thúc với một Timer còn sống.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('Banner hiện được cả khi đang mở một màn đẩy lên',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_host(navKey: navKey));
    await tester.pump();

    // Đẩy một màn lên, đúng như mở chi tiết tin tuyển dụng.
    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('chi tiết'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('chi tiết'), findsOneWidget);

    NotificationsStore.instance.debugEmit(const NotificationItem(
      id: 'n9',
      title: 'Xong nhiệm vụ',
      body: '',
      isRead: false,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Đây là điều đáng kiểm: trước khi sửa, host nằm TRONG route đầu tiên nên
    // màn đẩy lên che mất banner và dòng này sẽ trượt.
    expect(find.text('Xong nhiệm vụ'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
