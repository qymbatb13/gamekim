import 'package:flutter_test/flutter_test.dart';

import 'package:noir_blocks/main.dart';

void main() {
  testWidgets('shows the Noir Blocks main menu', (WidgetTester tester) async {
    await tester.pumpWidget(const NoirApp());

    expect(find.text('BEST SCORE'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
  });
}
