import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/app.dart';
import 'package:nextplease_mobile/features/onboarding/splash_page.dart';

void main() {
  testWidgets('Mở app thì hiện màn hình chào', (tester) async {
    await tester.pumpWidget(const NextPleaseApp());
    expect(find.byType(SplashPage), findsOneWidget);
  });
}
