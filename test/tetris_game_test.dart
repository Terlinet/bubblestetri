import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:terlinet_bubbles_chain/tetris_game.dart';

void main() {
  group('TetrisGame', () {
    test('keeps the active piece inside the board when moved', () {
      final game = TetrisGame(random: Random(4));

      for (var i = 0; i < TetrisGame.columns; i++) {
        game.moveHorizontal(-1);
      }

      final piece = game.activePiece!;
      expect(piece.x, 0);
      expect(piece.cells.every((cell) => piece.x + cell.x >= 0), isTrue);
    });

    test('hard drop locks the piece and spawns the next one', () {
      final game = TetrisGame(random: Random(4));
      final firstPiece = game.activePiece;

      game.hardDrop();

      final occupiedCells = game.board
          .expand((row) => row)
          .where((cell) => cell != 0)
          .length;
      expect(occupiedCells, 4);
      expect(game.activePiece, isNotNull);
      expect(game.activePiece, isNot(same(firstPiece)));
    });

    test('pause prevents the board from advancing', () {
      final game = TetrisGame(random: Random(4))..isPaused = true;
      final originalY = game.activePiece!.y;

      game.tick();

      expect(game.activePiece!.y, originalY);
    });
  });
}
