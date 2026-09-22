// Cổng đồng ý điều khoản.
//
// Kiểm ở đây chứ không trên máy ảo vì trạng thái cần thử là "tài khoản CHƯA
// từng đồng ý" — tài khoản thật đã đồng ý trên web rồi, và dựng lại trạng
// thái đó nghĩa là xoá bản ghi đồng ý trong DB thật. Điều kiện chặn thì kiểm
// được trọn vẹn ở đây.
//
// Cổng này chặn toàn bộ app, nên hai lỗi đối xứng đều nghiêm trọng: chặn
// nhầm người đã đồng ý, và cho qua người chưa đồng ý.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/core/theme.dart';
import 'package:nextplease_mobile/features/legal/consent_gate.dart';
import 'package:nextplease_mobile/features/legal/legal.dart';
import 'package:nextplease_mobile/features/profile/me_store.dart';

/// Dựng đúng cách app thật dùng: cổng nằm ở MaterialApp.builder, tức TRÊN
/// Navigator, để nó phủ lên cả những màn được đẩy lên.
Widget _host({required bool enabled}) => MaterialApp(
      theme: buildNpTheme(Brightness.light),
      builder: (context, child) => ConsentGate(
        enabled: enabled,
        onDecline: () async {},
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Center(child: Text('nội dung'))),
    );

/// Giả lập /profiles/me đã trả về.
void _profile({String? version}) {
  MeStore.instance.raw = {
    if (version != null) 'legalConsentVersion': version,
  };
  MeStore.instance.loaded = true;
}

void main() {
  tearDown(MeStore.instance.clear);

  testWidgets('Khách xem dạo thì không bị chặn', (tester) async {
    _profile();  // chưa đồng ý bao giờ
    await tester.pumpWidget(_host(enabled: false));
    expect(find.text('Trước khi bắt đầu'), findsNothing);
    expect(find.text('nội dung'), findsOneWidget);
  });

  testWidgets('Chưa biết hồ sơ thì KHÔNG chặn', (tester) async {
    // loaded == false nghĩa là chưa có câu trả lời. Chặn lúc này thì cổng
    // nháy lên ở mỗi lần mở app, kể cả với người đã đồng ý từ lâu.
    MeStore.instance.raw = const {};
    MeStore.instance.loaded = false;
    await tester.pumpWidget(_host(enabled: true));
    expect(find.text('Trước khi bắt đầu'), findsNothing);
  });

  testWidgets('Đã đăng nhập mà chưa đồng ý thì bị chặn', (tester) async {
    _profile();
    await tester.pumpWidget(_host(enabled: true));
    expect(find.text('Trước khi bắt đầu'), findsOneWidget);
    expect(find.text('Tôi đồng ý'), findsOneWidget);
    expect(find.text('Không đồng ý và đăng xuất'), findsOneWidget);
  });

  testWidgets('Đồng ý bản CŨ vẫn bị chặn', (tester) async {
    _profile(version: '2020-01-01');
    await tester.pumpWidget(_host(enabled: true));
    expect(find.text('Trước khi bắt đầu'), findsOneWidget);
  });

  testWidgets('Đã đồng ý đúng bản hiện hành thì đi thẳng vào app',
      (tester) async {
    _profile(version: kLegalVersion);
    await tester.pumpWidget(_host(enabled: true));
    expect(find.text('Trước khi bắt đầu'), findsNothing);
    expect(find.text('nội dung'), findsOneWidget);
  });

  testWidgets('Cổng phủ lên cả màn được đẩy lên', (tester) async {
    // Đặt trong `home:` thì một route mới sẽ che mất cổng và người dùng dùng
    // tiếp như chưa có gì — đúng lỗi đã xảy ra với banner thông báo.
    final navKey = GlobalKey<NavigatorState>();
    _profile();
    await tester.pumpWidget(MaterialApp(
      theme: buildNpTheme(Brightness.light),
      navigatorKey: navKey,
      builder: (context, child) => ConsentGate(
        enabled: true,
        onDecline: () async {},
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Center(child: Text('nội dung'))),
    ));

    navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('màn khác'))));
    await tester.pumpAndSettle();

    expect(find.text('Trước khi bắt đầu'), findsOneWidget);
  });
}
