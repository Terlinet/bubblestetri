import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:terlinet_bubbles_chain/coordenar_game.dart';

void main() {
  group('CoordenarGame', () {
    test('accepts matching shapes and scores each only once', () {
      final game = CoordenarGame(random: Random(4));
      final shape = game.targets.first;

      expect(game.place(shape, shape), MatchResult.correct);
      expect(game.score, 100);
      expect(game.isMatched(shape), isTrue);
      expect(game.place(shape, shape), MatchResult.alreadyMatched);
      expect(game.score, 100);
    });

    test('counts an incorrect placement without marking a shape', () {
      final game = CoordenarGame(random: Random(4));
      final target = game.targets.first;
      final wrongPiece = game.pieces.firstWhere((shape) => shape != target);

      expect(game.place(wrongPiece, target), MatchResult.incorrect);
      expect(game.mistakes, 1);
      expect(game.isMatched(target), isFalse);
      expect(game.score, 0);
    });

    test('starts the next round only after all shapes are placed', () {
      final game = CoordenarGame(random: Random(4));

      expect(game.landscape, IslandLandscape.desert);
      game.nextRound();
      expect(game.round, 1);

      for (final shape in game.targets) {
        expect(game.place(shape, shape), MatchResult.correct);
      }
      game.nextRound();

      expect(game.round, 2);
      expect(game.landscape, IslandLandscape.forest);
      expect(game.isRoundComplete, isFalse);
      expect(game.score, 400);
    });

    test('cycles through distinct landscapes as rounds advance', () {
      final game = CoordenarGame(random: Random(4));
      final landscapes = <IslandLandscape>[game.landscape];

      for (var round = 0; round < IslandLandscape.values.length * 2; round++) {
        for (final shape in game.targets) {
          game.place(shape, shape);
        }
        game.nextRound();
        landscapes.add(game.landscape);
      }

      expect(landscapes, [
        IslandLandscape.desert,
        IslandLandscape.forest,
        IslandLandscape.snowyMountains,
        IslandLandscape.volcano,
        IslandLandscape.desert,
        IslandLandscape.forest,
        IslandLandscape.snowyMountains,
        IslandLandscape.volcano,
        IslandLandscape.desert,
      ]);
    });
  });
}
