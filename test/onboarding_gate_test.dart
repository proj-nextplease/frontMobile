import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/core/theme.dart';
import 'package:nextplease_mobile/features/onboarding/onboarding_gate.dart';
import 'package:nextplease_mobile/features/profile/me_store.dart';

Widget _host({required bool enabled}) => MaterialApp(
      theme: buildNpTheme(Brightness.light),
      builder: (context, child) => OnboardingGate(
        enabled: enabled,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Center(child: Text('nội dung app'))),
    );

void _profile({bool onboardingCompleted = false, String name = 'Nguyễn Văn A'}) {
  MeStore.instance.raw = {
    'name': name,
    'onboardingCompleted': onboardingCompleted,
    'avatar': {'mascot': 'bald'},
    'skills': <String>['Flutter'],
  };
  MeStore.instance.name = name;
  MeStore.instance.onboardingCompleted = onboardingCompleted;
  MeStore.instance.loaded = true;
}

void main() {
  tearDown(MeStore.instance.clear);

  testWidgets('Khách chưa đăng nhập thì không bị chặn', (tester) async {
    _profile(onboardingCompleted: false);
    await tester.pumpWidget(_host(enabled: false));
    expect(find.text('Chào mừng bạn!'), findsNothing);
    expect(find.text('nội dung app'), findsOneWidget);
  });

  testWidgets('Hồ sơ chưa nạp xong thì không chặn sớm', (tester) async {
    MeStore.instance.raw = const {};
    MeStore.instance.loaded = false;
    await tester.pumpWidget(_host(enabled: true));
    expect(find.text('Chào mừng bạn!'), findsNothing);
    expect(find.text('nội dung app'), findsOneWidget);
  });

  testWidgets('Đã hoàn tất onboarding thì vào thẳng app', (tester) async {
    _profile(onboardingCompleted: true);
    await tester.pumpWidget(_host(enabled: true));
    expect(find.text('Chào mừng bạn!'), findsNothing);
    expect(find.text('nội dung app'), findsOneWidget);
  });

  testWidgets('Chưa hoàn tất onboarding thì hiện Wizard 3 bước', (tester) async {
    _profile(onboardingCompleted: false);
    await tester.pumpWidget(_host(enabled: true));
    expect(find.text('Chào mừng bạn!'), findsOneWidget);
    expect(find.text('Bước 1 / 3'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Để sau'), findsOneWidget);
  });

  testWidgets('Bấm Để sau thì đóng cổng và vào xem nội dung app', (tester) async {
    _profile(onboardingCompleted: false);
    await tester.pumpWidget(_host(enabled: true));
    expect(find.text('Chào mừng bạn!'), findsOneWidget);

    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng bạn!'), findsNothing);
    expect(find.text('nội dung app'), findsOneWidget);
  });

  testWidgets('Chuyển lần lượt qua 3 bước của Wizard', (tester) async {
    _profile(onboardingCompleted: false);
    await tester.pumpWidget(_host(enabled: true));

    // Bước 1
    expect(find.text('Bước 1 / 3'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    // Bước 2
    expect(find.text('Bước 2 / 3'), findsOneWidget);
    expect(find.text('Kỹ năng của bạn'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    // Bước 3
    expect(find.text('Bước 3 / 3'), findsOneWidget);
    expect(find.text('Định hướng nghề nghiệp'), findsOneWidget);
    expect(find.text('Hoàn tất hồ sơ (+50 EXP)'), findsOneWidget);
  });
}
