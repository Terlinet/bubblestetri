import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terlinet_bubbles_chain/gesture_navigation.dart';

void main() {
  testWidgets('shows global gesture controls above app routes', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Center(child: Text('Menu'))),
        builder: (context, child) => GestureNavigationOverlay(
          onRepeatIntroduction: () async {},
          child: child!,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
