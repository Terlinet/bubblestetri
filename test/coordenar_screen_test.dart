import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terlinet_bubbles_chain/coordenar_screen.dart';

void main() {
  for (final size in [const Size(400, 800), const Size(1000, 600)]) {
    testWidgets('shows the game without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: CoordenarScreen()));
      await tester.pump();

      expect(find.text('COORDENAR'), findsOneWidget);
      expect(find.text('ILHA DAS FORMAS'), findsOneWidget);
      expect(find.text('DESERTO'), findsOneWidget);
      expect(find.byTooltip('Ativar controle por mãos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
