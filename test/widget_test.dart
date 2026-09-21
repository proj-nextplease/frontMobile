// Kiểm thử khói: app dựng được và màn hình mở app hiện đúng.
//
// Chỉ dừng ở màn hình splash. Các màn hình sau cần Supabase đã khởi tạo và
// mạng thật, nên phần đó thuộc về kiểm thử tích hợp chứ không phải ở đây.
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/app.dart';

void main() {
  testWidgets('Mở app thì hiện màn hình chào với wordmark', (tester) async {
    await tester.pumpWidget(const NextPleaseApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('nextplease'), findsOneWidget);
    expect(find.text('Hồ sơ dựa trên bằng chứng'), findsOneWidget);
  });
}
