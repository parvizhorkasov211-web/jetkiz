import 'package:flutter_test/flutter_test.dart';
import 'package:jetkiz_mobile/app/app.dart';

void main() {
  testWidgets('Jetkiz app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const JetkizApp());
    expect(find.text('Рестораны'), findsOneWidget);
  });
}
