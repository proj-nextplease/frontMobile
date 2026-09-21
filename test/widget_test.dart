// Kiểm thử khói: app dựng được và hiện khung màn hình Cơ hội.
//
// Không gọi API thật ở đây — JobsPage tự nạp dữ liệu khi khởi tạo, nên phần
// kiểm thử chỉ xác nhận app không vỡ lúc dựng và tiêu đề đúng. Kiểm thử cho
// tầng dữ liệu sẽ tách riêng khi có lớp inject repository.
import 'package:flutter_test/flutter_test.dart';
import 'package:nextplease_mobile/main.dart';

void main() {
  testWidgets('App dựng được và hiện tiêu đề Cơ hội', (tester) async {
    await tester.pumpWidget(const NextPleaseApp());
    expect(find.text('Cơ hội'), findsOneWidget);
  });
}
