import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terlinet_bubbles_chain/gesture_navigation.dart';
import 'package:terlinet_bubbles_chain/hand_tracking.dart';

void main() {
  testWidgets('shows hand tracking cursor on the home screen', (tester) async {
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

  testWidgets('home gestures do not click controls on a game route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigatorKey = GlobalKey<NavigatorState>();
    var gameButtonPresses = 0;
    final tracking = HandTrackingService.instance;
    addTearDown(() {
      tracking.pose.value = null;
      tracking.isActive.value = false;
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const GestureNavigationOverlay(
          child: Scaffold(body: Center(child: Text('Menu'))),
        ),
      ),
    );
    await tester.pump();
    tracking.isActive.value = true;
    tracking.pose.value = const HandPose(x: 0.5, y: 0.5, isPinching: false);

    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => gameButtonPresses++,
              child: const Text('Game action'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tracking.pose.value = const HandPose(x: 0.5, y: 0.5, isPinching: true);
    await tester.pump();

    expect(gameButtonPresses, 0);
    expect(find.text('Game action'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
