import 'dart:math' as math;

enum Tetromino {
  i(0xFF00F5FF, [
    [0, 1],
    [1, 1],
    [2, 1],
    [3, 1],
  ]),
  o(0xFFFFD166, [
    [1, 1],
    [2, 1],
    [1, 2],
    [2, 2],
  ]),
  t(0xFFB05CFF, [
    [0, 1],
    [1, 1],
    [2, 1],
    [1, 2],
  ]),
  j(0xFF5271FF, [
    [0, 1],
    [0, 2],
    [1, 2],
    [2, 2],
  ]),
  l(0xFFFF9E45, [
    [2, 1],
    [0, 2],
    [1, 2],
    [2, 2],
  ]),
  s(0xFF71F79F, [
    [1, 1],
    [2, 1],
    [0, 2],
    [1, 2],
  ]),
  z(0xFFFF5C9A, [
    [0, 1],
    [1, 1],
    [1, 2],
    [2, 2],
  ]);

  const Tetromino(this.colorValue, this.startCells);

  final int colorValue;
  final List<List<int>> startCells;
}

class TetrisCell {
  const TetrisCell(this.x, this.y);

  final int x;
  final int y;
}

class ActivePiece {
  ActivePiece(this.type, this.x, this.y);

  final Tetromino type;
  int x;
  int y;
  int rotation = 0;

  List<TetrisCell> get cells {
    final rotated = type.startCells.map((cell) {
      var x = cell[0];
      var y = cell[1];
      for (var turn = 0; turn < rotation; turn++) {
        final nextX = 3 - y;
        y = x;
        x = nextX;
      }
      return TetrisCell(x, y);
    }).toList();
    final minX = rotated.map((cell) => cell.x).reduce(math.min);
    final minY = rotated.map((cell) => cell.y).reduce(math.min);
    return rotated
        .map((cell) => TetrisCell(cell.x - minX, cell.y - minY))
        .toList();
  }

  int get width => cells.map((cell) => cell.x).reduce(math.max) + 1;
}

class TetrisGame {
  TetrisGame({math.Random? random}) : _random = random ?? math.Random() {
    _nextType = _randomType();
    _spawnPiece();
  }

  static const columns = 10;
  static const rows = 20;

  final math.Random _random;
  List<List<int>> _board = _emptyBoard();
  late Tetromino _nextType;
  ActivePiece? _activePiece;
  int score = 0;
  int lines = 0;
  bool isGameOver = false;
  bool isPaused = false;

  List<List<int>> get board =>
      _board.map((row) => List<int>.unmodifiable(row)).toList();
  ActivePiece? get activePiece => _activePiece;
  Tetromino get nextType => _nextType;

  static List<List<int>> _emptyBoard() =>
      List.generate(rows, (_) => List.filled(columns, 0));

  Tetromino _randomType() =>
      Tetromino.values[_random.nextInt(Tetromino.values.length)];

  void _spawnPiece() {
    final type = _nextType;
    _nextType = _randomType();
    final piece = ActivePiece(type, 0, 0);
    piece.x = (columns - piece.width) ~/ 2;
    if (_collides(piece, piece.x, piece.y)) {
      isGameOver = true;
      _activePiece = null;
      return;
    }
    _activePiece = piece;
  }

  bool _collides(ActivePiece piece, int x, int y, {int? rotation}) {
    final previousRotation = piece.rotation;
    if (rotation != null) piece.rotation = rotation;
    final cells = piece.cells;
    piece.rotation = previousRotation;

    for (final cell in cells) {
      final boardX = x + cell.x;
      final boardY = y + cell.y;
      if (boardX < 0 ||
          boardX >= columns ||
          boardY >= rows ||
          (boardY >= 0 && _board[boardY][boardX] != 0)) {
        return true;
      }
    }
    return false;
  }

  bool moveHorizontal(int direction) {
    if (isGameOver || isPaused) return false;
    final piece = _activePiece;
    if (piece == null) return false;
    final nextX = (piece.x + direction).clamp(0, columns - piece.width);
    if (_collides(piece, nextX, piece.y)) return false;
    piece.x = nextX;
    return true;
  }

  bool moveToColumn(int column) {
    if (isGameOver || isPaused) return false;
    final piece = _activePiece;
    if (piece == null) return false;
    final nextX = column.clamp(0, columns - piece.width);
    if (_collides(piece, nextX, piece.y)) return false;
    piece.x = nextX;
    return true;
  }

  bool rotate() {
    if (isGameOver || isPaused) return false;
    final piece = _activePiece;
    if (piece == null) return false;
    final nextRotation = (piece.rotation + 1) % 4;
    for (final offset in [0, -1, 1, -2, 2]) {
      final nextX = (piece.x + offset).clamp(0, columns - 1);
      if (!_collides(piece, nextX, piece.y, rotation: nextRotation)) {
        piece
          ..rotation = nextRotation
          ..x = nextX;
        return true;
      }
    }
    return false;
  }

  void tick() {
    if (isGameOver || isPaused) return;
    final piece = _activePiece;
    if (piece == null) return;
    if (!_collides(piece, piece.x, piece.y + 1)) {
      piece.y++;
    } else {
      _lockPiece();
    }
  }

  void softDrop() {
    if (isGameOver || isPaused) return;
    final piece = _activePiece;
    if (piece == null) return;
    if (!_collides(piece, piece.x, piece.y + 1)) {
      piece.y++;
      score++;
    } else {
      _lockPiece();
    }
  }

  void hardDrop() {
    if (isGameOver || isPaused) return;
    final piece = _activePiece;
    if (piece == null) return;
    while (!_collides(piece, piece.x, piece.y + 1)) {
      piece.y++;
      score += 2;
    }
    _lockPiece();
  }

  void _lockPiece() {
    final piece = _activePiece;
    if (piece == null) return;
    for (final cell in piece.cells) {
      final x = piece.x + cell.x;
      final y = piece.y + cell.y;
      if (y < 0) {
        isGameOver = true;
        _activePiece = null;
        return;
      }
      _board[y][x] = piece.type.index + 1;
    }

    final remainingRows = _board.where((row) => row.any((cell) => cell == 0));
    final cleared = rows - remainingRows.length;
    if (cleared > 0) {
      _board = [
        ...List.generate(cleared, (_) => List.filled(columns, 0)),
        ...remainingRows.map((row) => List<int>.from(row)),
      ];
      lines += cleared;
      score += const [0, 100, 300, 500, 800][cleared];
    }
    _spawnPiece();
  }

  int get landingY {
    final piece = _activePiece;
    if (piece == null) return 0;
    var y = piece.y;
    while (!_collides(piece, piece.x, y + 1)) {
      y++;
    }
    return y;
  }

  void reset() {
    _board = _emptyBoard();
    score = 0;
    lines = 0;
    isGameOver = false;
    isPaused = false;
    _nextType = _randomType();
    _spawnPiece();
  }
}
