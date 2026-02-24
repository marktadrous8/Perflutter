import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('loads performance use cases screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PerflutterExampleApp());
    expect(find.text('Perflutter Example Use Cases'), findsOneWidget);
  });
}
