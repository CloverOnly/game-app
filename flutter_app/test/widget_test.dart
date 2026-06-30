import 'package:flutter_test/flutter_test.dart';

import 'package:land_grabber_mobile/main.dart';

void main() {
  testWidgets('메뉴 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const LandGrabberApp());

    expect(find.text('AI 대전'), findsOneWidget);
    expect(find.text('로컬 대전'), findsOneWidget);
    expect(find.text('PVP 모드'), findsOneWidget);
  });
}
