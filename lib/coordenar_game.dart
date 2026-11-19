import 'dart:math' as math;

enum GeometricShape {
  circle('Círculo', 0xFF00F5FF),
  square('Quadrado', 0xFFFFB547),
  triangle('Triângulo', 0xFFB05CFF),
  diamond('Losango', 0xFFFF5C9A);

  const GeometricShape(this.label, this.colorValue);

  final String label;
  final int colorValue;
}

enum MatchResult { correct, incorrect, alreadyMatched }

enum IslandLandscape {
  desert('Deserto'),
  forest('Floresta'),
  snowyMountains('Montanhas nevadas'),
  volcano('Vulcão');

  const IslandLandscape(this.label);

  final String label;

  static IslandLandscape forRound(int round) =>
      values[(round - 1) % values.length];
}

class CoordenarGame {
  CoordenarGame({math.Random? random}) : _random = random ?? math.Random() {
    _prepareRound();
  }

  final math.Random _random;
  List<GeometricShape> _targets = [];
  List<GeometricShape> _pieces = [];
  final Set<GeometricShape> _matched = {};

  int round = 1;
  int score = 0;
  int mistakes = 0;

  List<GeometricShape> get targets => List.unmodifiable(_targets);
  List<GeometricShape> get pieces => List.unmodifiable(_pieces);
  Set<GeometricShape> get matched => Set.unmodifiable(_matched);
  bool get isRoundComplete => _matched.length == _targets.length;
  IslandLandscape get landscape => IslandLandscape.forRound(round);

  bool isMatched(GeometricShape shape) => _matched.contains(shape);

  MatchResult place(GeometricShape piece, GeometricShape target) {
    if (_matched.contains(piece) || _matched.contains(target)) {
      return MatchResult.alreadyMatched;
    }
    if (piece != target) {
      mistakes++;
      return MatchResult.incorrect;
    }
    _matched.add(target);
    score += 100;
    return MatchResult.correct;
  }

  void nextRound() {
    if (!isRoundComplete) return;
    round++;
    _prepareRound();
  }

  void reset() {
    round = 1;
    score = 0;
    mistakes = 0;
    _prepareRound();
  }

  void _prepareRound() {
    _targets = List.of(GeometricShape.values)..shuffle(_random);
    _pieces = List.of(_targets)..shuffle(_random);
    _matched.clear();
  }
}
