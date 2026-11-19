import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hand_tracking.dart';
import 'tetris_game.dart';

class TetrisScreen extends StatefulWidget {
  const TetrisScreen({super.key});

  @override
  State<TetrisScreen> createState() => _TetrisScreenState();
}

class _TetrisScreenState extends State<TetrisScreen> {
  final TetrisGame _game = TetrisGame();
  final HandTrackingService _handTracking = HandTrackingService.instance;
  bool _cameraActive = false;
  bool _cameraBusy = false;
  bool _isPinching = false;
  double? _rotationAnchorY;
  String _cameraStatus = 'Câmera desligada';

  @override
  void initState() {
    super.initState();
    _cameraActive = _handTracking.isActive.value;
    _cameraStatus = _handTracking.status.value;
    _handTracking.pose.addListener(_syncHandPose);
    _handTracking.status.addListener(_syncCameraStatus);
    _handTracking.isActive.addListener(_syncCameraState);
  }

  void _syncHandPose() => _handleHandPose(_handTracking.pose.value);

  void _syncCameraStatus() {
    if (mounted) setState(() => _cameraStatus = _handTracking.status.value);
  }

  void _syncCameraState() {
    if (!mounted) return;
    setState(() {
      _cameraActive = _handTracking.isActive.value;
      if (!_cameraActive) {
        _isPinching = false;
        _rotationAnchorY = null;
      }
    });
  }

  void _handleHandPose(HandPose? pose) {
    if (!mounted || pose == null) {
      _isPinching = false;
      _rotationAnchorY = null;
      return;
    }

    if (pose.isPinching) {
      final piece = _game.activePiece;
      if (piece != null) {
        final targetColumn = (pose.x * TetrisGame.columns - piece.width / 2)
            .round();
        _game.moveToColumn(targetColumn);
      }
      if (!_isPinching) {
        _rotationAnchorY = pose.y;
      } else if (_rotationAnchorY != null &&
          _rotationAnchorY! - pose.y > 0.18) {
        _game.rotate();
        _rotationAnchorY = pose.y;
      }
      _isPinching = true;
    } else if (_isPinching) {
      _game.hardDrop();
      _isPinching = false;
      _rotationAnchorY = null;
    }
    setState(() {});
  }

  Future<void> _toggleCamera() async {
    if (_cameraBusy || _handTracking.isBusy) return;
    setState(() => _cameraBusy = true);
    try {
      if (_handTracking.isActive.value) {
        await _handTracking.stop();
      } else {
        await _handTracking.start();
      }
    } catch (error, stackTrace) {
      debugPrint('Could not start hand tracking: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _cameraActive = false;
          _cameraStatus = error is UnsupportedError
              ? error.message?.toString() ??
                    'Rastreamento disponível na versão Web.'
              : 'Câmera indisponível. Verifique a permissão e tente novamente.';
        });
        _handTracking.status.value = _cameraStatus;
      }
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  void _performMove(bool Function() action) {
    if (_game.isGameOver) return;
    setState(action);
  }

  void _togglePause() {
    if (_game.isGameOver) return;
    setState(() => _game.isPaused = !_game.isPaused);
  }

  void _restart() {
    setState(_game.reset);
  }

  @override
  void dispose() {
    _handTracking.pose.removeListener(_syncHandPose);
    _handTracking.status.removeListener(_syncCameraStatus);
    _handTracking.isActive.removeListener(_syncCameraState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080512),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 620) {
                    return _buildWideLayout(constraints);
                  }
                  return _buildCompactLayout();
                },
              ),
            ),
            _buildControls(),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'PEÇA PARADA  ·  FECHE A PINÇA: POSICIONAR  ·  SUBA A MÃO: GIRAR  ·  ABRA A PINÇA: LANÇAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFB5A7D6),
                  fontFamily: 'monospace',
                  fontSize: 9,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xFF00F5FF),
            tooltip: 'Voltar',
          ),
          const Expanded(
            child: Text(
              'BUBBLES TETRIS',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          _buildStat('PONTOS', _game.score),
          const SizedBox(width: 14),
          _buildStat('LINHAS', _game.lines),
          IconButton(
            onPressed: _game.isGameOver ? null : _togglePause,
            icon: Icon(
              _game.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            ),
            color: const Color(0xFFFF2BD6),
            tooltip: _game.isPaused ? 'Continuar' : 'Pausar',
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB5A7D6),
            fontFamily: 'monospace',
            fontSize: 8,
            letterSpacing: 1,
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            color: Color(0xFF00F5FF),
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    final boardWidth = math.min(390.0, constraints.maxHeight * 0.48);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: boardWidth,
          child: Center(child: _buildBoard()),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 205,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNextPieceCard(),
              const SizedBox(height: 18),
              _buildCameraPanel(compact: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: _buildCameraPanel(compact: true),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildBoard(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * 0.5,
        );
        return SizedBox(
          width: width,
          height: width * 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _TetrisBoardPainter(_game)),
              if (_game.isPaused || _game.isGameOver)
                ColoredBox(
                  color: const Color(0xC9080512),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _game.isGameOver ? 'FIM DE JOGO' : 'PAUSADO',
                          style: const TextStyle(
                            color: Color(0xFFFF2BD6),
                            fontFamily: 'monospace',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        if (_game.isGameOver) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _restart,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('JOGAR DE NOVO'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNextPieceCard() {
    return _neonPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          const Text(
            'PRÓXIMA PEÇA',
            style: TextStyle(
              color: Color(0xFFB5A7D6),
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 76,
            height: 66,
            child: CustomPaint(painter: _NextPiecePainter(_game.nextType)),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPanel({required bool compact}) {
    if (compact) {
      return _neonPanel(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(
              width: 102,
              height: 68,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: _buildCameraPreview(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildCameraStatus()),
            const SizedBox(width: 8),
            _buildCameraButton(),
          ],
        ),
      );
    }

    return _neonPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 138,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildCameraPreview(),
            ),
          ),
          const SizedBox(height: 10),
          _buildCameraStatus(),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _buildCameraButton()),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return ColoredBox(
      color: const Color(0xFF120B24),
      child: Center(
        child: Icon(
          _cameraActive ? Icons.front_hand_rounded : Icons.videocam_outlined,
          size: 32,
          color: const Color(0xFF00F5FF),
        ),
      ),
    );
  }

  Widget _buildCameraStatus() {
    return Text(
      _cameraStatus,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFFD8FBFF),
        fontFamily: 'monospace',
        fontSize: 9,
      ),
    );
  }

  Widget _buildCameraButton() {
    return FilledButton.tonalIcon(
      onPressed: _cameraBusy ? null : _toggleCamera,
      icon: _cameraBusy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_cameraActive ? Icons.videocam_off_rounded : Icons.camera_alt),
      label: Text(_cameraActive ? 'DESLIGAR' : 'ATIVAR CÂMERA'),
      style: FilledButton.styleFrom(
        foregroundColor: const Color(0xFF00F5FF),
        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 9),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _neonPanel({required Widget child, required EdgeInsets padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xCC120B24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x5500F5FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F5FF).withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _controlButton(Icons.arrow_left_rounded, 'Mover à esquerda', () {
            _performMove(() => _game.moveHorizontal(-1));
          }),
          _controlButton(Icons.arrow_downward_rounded, 'Descer', () {
            _performMove(() {
              _game.softDrop();
              return true;
            });
          }),
          _controlButton(Icons.rotate_right_rounded, 'Girar peça', () {
            _performMove(_game.rotate);
          }),
          _controlButton(Icons.arrow_right_rounded, 'Mover à direita', () {
            _performMove(() => _game.moveHorizontal(1));
          }),
          _controlButton(
            Icons.vertical_align_bottom_rounded,
            'Soltar peça',
            () {
              _performMove(() {
                _game.hardDrop();
                return true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      color: const Color(0xFF00F5FF),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF171027),
        minimumSize: const Size(44, 44),
      ),
    );
  }
}

class _TetrisBoardPainter extends CustomPainter {
  _TetrisBoardPainter(this.game);

  final TetrisGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / TetrisGame.columns;
    final cellHeight = size.height / TetrisGame.rows;
    final boardRect = Offset.zero & size;

    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(12)),
      Paint()..color = const Color(0xFF0B0817),
    );

    final board = game.board;
    for (var y = 0; y < TetrisGame.rows; y++) {
      for (var x = 0; x < TetrisGame.columns; x++) {
        final typeId = board[y][x];
        if (typeId != 0) {
          _drawCell(
            canvas,
            x,
            y,
            cellWidth,
            cellHeight,
            Color(Tetromino.values[typeId - 1].colorValue),
          );
        }
      }
    }

    final piece = game.activePiece;
    if (piece != null) {
      for (final cell in piece.cells) {
        _drawCell(
          canvas,
          piece.x + cell.x,
          game.landingY + cell.y,
          cellWidth,
          cellHeight,
          Color(Tetromino.values[piece.type.index].colorValue)
              .withValues(alpha: 0.18),
          outlineOnly: true,
        );
      }
      for (final cell in piece.cells) {
        _drawCell(
          canvas,
          piece.x + cell.x,
          piece.y + cell.y,
          cellWidth,
          cellHeight,
          Color(Tetromino.values[piece.type.index].colorValue),
        );
      }
    }

    final gridPaint = Paint()
      ..color = const Color(0xFF8F74BD).withValues(alpha: 0.14)
      ..strokeWidth = 0.6;
    for (var x = 0; x <= TetrisGame.columns; x++) {
      canvas.drawLine(
        Offset(x * cellWidth, 0),
        Offset(x * cellWidth, size.height),
        gridPaint,
      );
    }
    for (var y = 0; y <= TetrisGame.rows; y++) {
      canvas.drawLine(
        Offset(0, y * cellHeight),
        Offset(size.width, y * cellHeight),
        gridPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        boardRect.deflate(0.7),
        const Radius.circular(12),
      ),
      Paint()
        ..color = const Color(0xFF00F5FF).withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _drawCell(
    Canvas canvas,
    int x,
    int y,
    double cellWidth,
    double cellHeight,
    Color color, {
    bool outlineOnly = false,
  }) {
    if (y < 0 || y >= TetrisGame.rows) return;
    final center = Offset((x + 0.5) * cellWidth, (y + 0.5) * cellHeight);
    final radius = math.min(cellWidth, cellHeight) * 0.44;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    if (!outlineOnly) {
      canvas.drawCircle(
        center,
        radius + 1.2,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.38, -0.48),
            radius: 0.92,
            colors: [
              Colors.white.withValues(alpha: 0.96),
              color.withValues(alpha: 0.92),
              color.withValues(alpha: 0.72),
              color.withValues(alpha: 0.38),
            ],
            stops: const [0, 0.12, 0.56, 1],
          ).createShader(bounds),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(-radius * 0.22, -radius * 0.43),
          width: radius * 0.58,
          height: radius * 0.2,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.64),
      );
      canvas.drawCircle(
        center + Offset(radius * 0.34, radius * 0.34),
        radius * 0.09,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    } else {
      canvas.drawCircle(
        center,
        radius * 0.86,
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TetrisBoardPainter oldDelegate) =>
      oldDelegate.game != game;
}

class _NextPiecePainter extends CustomPainter {
  _NextPiecePainter(this.type);

  final Tetromino type;

  @override
  void paint(Canvas canvas, Size size) {
    final piece = ActivePiece(type, 0, 0);
    final cellWidth = size.width / 4;
    final cellHeight = size.height / 4;
    final color = Color(type.colorValue);
    for (final cell in piece.cells) {
      final center = Offset(
        (cell.x + (4 - piece.width) / 2 + 0.5) * cellWidth,
        (cell.y + 1) * cellHeight,
      );
      final radius = math.min(cellWidth, cellHeight) * 0.36;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.38, -0.48),
            colors: [
              Colors.white.withValues(alpha: 0.9),
              color,
              color.withValues(alpha: 0.7),
            ],
            stops: const [0, 0.18, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(-radius * 0.2, -radius * 0.4),
          width: radius * 0.5,
          height: radius * 0.18,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NextPiecePainter oldDelegate) =>
      oldDelegate.type != type;
}
