import 'package:flutter_test/flutter_test.dart';

import 'package:land_grabber_mobile/main.dart';

void main() {
  testWidgets('메뉴 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const LandGrabberApp());

    expect(find.text('대격돌!'), findsOneWidget);
    expect(find.text('땅따먹기'), findsOneWidget);
    expect(find.text('▶  1:1 대전 시작'), findsOneWidget);
  });
}
