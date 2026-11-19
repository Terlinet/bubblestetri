import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'coordenar_game.dart';
import 'hand_tracking.dart';

class CoordenarScreen extends StatefulWidget {
  const CoordenarScreen({super.key});

  @override
  State<CoordenarScreen> createState() => _CoordenarScreenState();
}

class _CoordenarScreenState extends State<CoordenarScreen> {
  static const _targetPositions = [
    Offset(0.18, 0.47),
    Offset(0.39, 0.405),
    Offset(0.61, 0.405),
    Offset(0.82, 0.47),
  ];
  static const _piecePositions = [
    Offset(0.18, 0.81),
    Offset(0.39, 0.81),
    Offset(0.61, 0.81),
    Offset(0.82, 0.81),
  ];

  final CoordenarGame _game = CoordenarGame();
  late final HandTrackingController _handTracking;
  Size _sceneSize = Size.zero;
  Offset _handPosition = const Offset(-1, -1);
  GeometricShape? _heldPiece;
  bool _isPinching = false;
  bool _handVisible = false;
  bool _cameraActive = false;
  bool _cameraBusy = false;
  bool _lastMoveWasCorrect = true;
  String _message = 'Feche a pinça sobre uma peça e mova a mão até a seta.';
  String _cameraStatus = 'Arraste as peças ou ative a câmera.';

  @override
  void initState() {
    super.initState();
    _handTracking = createHandTrackingController(
      onPose: _handleHandPose,
      onStatus: (status) {
        if (mounted) setState(() => _cameraStatus = status);
      },
    );
  }

  void _handleHandPose(HandPose? pose) {
    if (!mounted) return;
    if (pose == null) {
      setState(() {
        _handVisible = false;
        if (_isPinching) {
          _isPinching = false;
          _heldPiece = null;
          _message = 'Mão não detectada. Mostre a mão para continuar.';
        }
      });
      return;
    }

    final position = Offset(
      pose.x.clamp(0.0, 1.0).toDouble(),
      pose.y.clamp(0.0, 1.0).toDouble(),
    );
    setState(() {
      _handVisible = true;
      _handPosition = position;
      if (pose.isPinching) {
        if (!_isPinching) {
          _heldPiece = _pieceAt(position);
          _message = _heldPiece == null
              ? 'Aproxime a mão de uma peça e feche a pinça.'
              : 'Peça na mão! Mova até a seta e abra a pinça.';
        }
        _isPinching = true;
      } else if (_isPinching) {
        _finishPlacement();
        _isPinching = false;
      }
    });
  }

  GeometricShape? _pieceAt(Offset position) {
    var closestDistance = double.infinity;
    GeometricShape? closestPiece;
    for (var index = 0; index < _game.pieces.length; index++) {
      final piece = _game.pieces[index];
      if (_game.isMatched(piece)) continue;
      final distance = _distance(position, _piecePositions[index]);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestPiece = piece;
      }
    }
    return closestDistance <= 0.13 ? closestPiece : null;
  }

  void _finishPlacement() {
    final piece = _heldPiece;
    _heldPiece = null;
    if (piece == null) return;

    var closestDistance = double.infinity;
    GeometricShape? target;
    for (var index = 0; index < _game.targets.length; index++) {
      final distance = _distance(_handPosition, _targetPositions[index]);
      if (distance < closestDistance) {
        closestDistance = distance;
        target = _game.targets[index];
      }
    }
    if (target == null || closestDistance > 0.15) {
      _message = 'Leve a peça até o espaço indicado pela seta.';
      return;
    }

    switch (_game.place(piece, target)) {
      case MatchResult.correct:
        _lastMoveWasCorrect = true;
        _message = _game.isRoundComplete
            ? 'Ilha completa! Pronto para a próxima fase.'
            : 'Muito bem! Pegue a próxima peça indicada.';
      case MatchResult.incorrect:
        _lastMoveWasCorrect = false;
        _message = 'Essa peça não encaixa aqui. Observe a forma da seta.';
      case MatchResult.alreadyMatched:
        _message = 'Esse espaço já está completo. Pegue outra peça.';
    }
  }

  double _distance(Offset a, Offset b) =>
      math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));

  void _startPointerDrag(Offset localPosition) {
    if (_sceneSize.isEmpty) return;
    _handlePointerPose(localPosition, pinching: true);
  }

  void _updatePointerDrag(Offset localPosition) {
    if (_sceneSize.isEmpty) return;
    _handlePointerPose(localPosition, pinching: true);
  }

  void _handlePointerPose(Offset point, {required bool pinching}) {
    _handleHandPose(
      HandPose(
        x: point.dx / _sceneSize.width,
        y: point.dy / _sceneSize.height,
        isPinching: pinching,
      ),
    );
  }

  void _endPointerDrag() {
    if (!_isPinching) return;
    _handleHandPose(
      HandPose(x: _handPosition.dx, y: _handPosition.dy, isPinching: false),
    );
  }

  Future<void> _toggleCamera() async {
    if (_cameraBusy) return;
    setState(() => _cameraBusy = true);
    try {
      if (_cameraActive) {
        await _handTracking.stop();
        if (!mounted) return;
        setState(() {
          _cameraActive = false;
          _isPinching = false;
          _heldPiece = null;
          _cameraStatus = 'Câmera desligada.';
        });
      } else {
        await _handTracking.start();
        if (!mounted) return;
        setState(() => _cameraActive = true);
      }
    } catch (error, stackTrace) {
      debugPrint('Could not start hand tracking: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _cameraActive = false;
          _cameraStatus = error is UnsupportedError
              ? error.message?.toString() ??
                    'Controle por mãos disponível na versão Web.'
              : 'Câmera indisponível. Verifique a permissão e tente novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  void _nextRound() {
    setState(() {
      _game.nextRound();
      _message = 'Nova ilha! Pegue a peça e siga a seta.';
      _lastMoveWasCorrect = true;
    });
  }

  void _restart() {
    setState(() {
      _game.reset();
      _heldPiece = null;
      _isPinching = false;
      _message = 'Feche a pinça sobre uma peça e mova a mão até a seta.';
      _lastMoveWasCorrect = true;
    });
  }

  @override
  void dispose() {
    _handTracking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101A32),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildScoreboard(),
            Expanded(child: _buildIslandScene()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 10, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xFFBDEBFF),
            tooltip: 'Voltar',
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COORDENAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'ILHA DAS FORMAS',
                  style: TextStyle(
                    color: Color(0xFFBDEBFF),
                    fontSize: 9,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _restart,
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFFFFCB65),
            tooltip: 'Recomeçar jogo',
          ),
          IconButton(
            onPressed: _cameraBusy ? null : _toggleCamera,
            tooltip: _cameraActive
                ? 'Desativar controle por mãos'
                : 'Ativar controle por mãos',
            icon: _cameraBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _cameraActive
                        ? Icons.videocam_rounded
                        : Icons.front_hand_rounded,
                  ),
            color: _cameraActive
                ? const Color(0xFF71F79F)
                : const Color(0xFFBDEBFF),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          _statCard('FASE', '${_game.round}'),
          const SizedBox(width: 7),
          _statCard('PONTOS', '${_game.score}'),
          const SizedBox(width: 7),
          _statCard('ERROS', '${_game.mistakes}'),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xAA142342),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x5538C9E8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$label  ',
              style: const TextStyle(
                color: Color(0xFFBDEBFF),
                fontSize: 8,
                letterSpacing: 0.7,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIslandScene() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _sceneSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _startPointerDrag(details.localPosition),
          onPanUpdate: (details) => _updatePointerDrag(details.localPosition),
          onPanEnd: (_) => _endPointerDrag(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _VoxelIslandPainter(
                  game: _game,
                  targetPositions: _targetPositions,
                  piecePositions: _piecePositions,
                  heldPiece: _heldPiece,
                  handPosition: _handPosition,
                  isPinching: _isPinching,
                ),
                child: const SizedBox.expand(),
              ),
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC172A46),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x99FFFFFF)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33233355),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Text(
                        _game.landscape.label.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_handVisible && _handPosition.dx >= 0)
                Positioned(
                  left: _handPosition.dx * _sceneSize.width - 18,
                  top: _handPosition.dy * _sceneSize.height - 18,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xDD172A46),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isPinching
                              ? const Color(0xFFFFCB65)
                              : const Color(0xFFBDEBFF),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38C9E8)
                                .withValues(alpha: 0.5),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          _isPinching
                              ? Icons.front_hand_rounded
                              : Icons.touch_app_rounded,
                          size: 20,
                          color: _isPinching
                              ? const Color(0xFFFFCB65)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    final complete = _game.isRoundComplete;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _lastMoveWasCorrect
                        ? Colors.white
                        : const Color(0xFFFFA8A8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cameraActive
                      ? _cameraStatus
                      : '$_cameraStatus  Toque e arraste também funciona.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFBDEBFF), fontSize: 9),
                ),
              ],
            ),
          ),
          if (complete) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _nextRound,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2D7D62),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text(
                'PRÓXIMA ILHA',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoxelIslandPainter extends CustomPainter {
  const _VoxelIslandPainter({
    required this.game,
    required this.targetPositions,
    required this.piecePositions,
    required this.heldPiece,
    required this.handPosition,
    required this.isPinching,
  });

  final CoordenarGame game;
  final List<Offset> targetPositions;
  final List<Offset> piecePositions;
  final GeometricShape? heldPiece;
  final Offset handPosition;
  final bool isPinching;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _IslandPalette.forLandscape(game.landscape);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.sky,
        ).createShader(rect),
    );
    _drawLandscapeBackdrop(canvas, size, palette);
    if (game.landscape != IslandLandscape.volcano) {
      _drawSun(canvas, size, palette.sun);
    }
    _drawCloud(
      canvas,
      size,
      Offset(size.width * 0.16, size.height * 0.16),
      0.8,
      palette.cloud,
    );
    _drawCloud(
      canvas,
      size,
      Offset(size.width * 0.77, size.height * 0.12),
      1,
      palette.cloud,
    );
    _drawIsland(canvas, size, palette);
    _drawLandscapeFeatures(canvas, size, palette);
    _drawPieceStand(canvas, size, palette);
    _drawTargets(canvas, size);
    _drawPieces(canvas, size);
    _drawGuidanceArrow(canvas, size);
  }

  Offset _point(Size size, Offset normalized) =>
      Offset(size.width * normalized.dx, size.height * normalized.dy);

  void _drawSun(Canvas canvas, Size size, Color color) {
    final center = Offset(size.width * 0.84, size.height * 0.17);
    canvas.drawCircle(center, 24, Paint()..color = color);
    canvas.drawCircle(
      center,
      32,
      Paint()
        ..color = color.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  void _drawCloud(
    Canvas canvas,
    Size size,
    Offset center,
    double scale,
    Color color,
  ) {
    final p = Paint()..color = color;
    final unit = math.min(size.width, size.height) * 0.055 * scale;
    final x = center.dx;
    final y = center.dy;
    canvas.drawRect(Rect.fromLTWH(x - unit, y, unit * 2.4, unit * 0.55), p);
    canvas.drawRect(
      Rect.fromLTWH(x - unit * 0.55, y - unit * 0.45, unit, unit),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + unit * 0.2, y - unit * 0.25, unit, unit * 0.8),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(x - unit * 1.35, y + unit * 0.2, unit * 0.35, unit * 0.35),
      p,
    );
  }

  void _drawLandscapeBackdrop(
    Canvas canvas,
    Size size,
    _IslandPalette palette,
  ) {
    final w = size.width;
    final h = size.height;
    switch (game.landscape) {
      case IslandLandscape.desert:
        final farDune = Path()
          ..moveTo(0, h * 0.39)
          ..quadraticBezierTo(w * 0.27, h * 0.24, w * 0.53, h * 0.38)
          ..quadraticBezierTo(w * 0.78, h * 0.51, w, h * 0.32)
          ..lineTo(w, h * 0.55)
          ..lineTo(0, h * 0.55)
          ..close();
        final nearDune = Path()
          ..moveTo(0, h * 0.48)
          ..quadraticBezierTo(w * 0.28, h * 0.34, w * 0.54, h * 0.47)
          ..quadraticBezierTo(w * 0.77, h * 0.58, w, h * 0.43)
          ..lineTo(w, h * 0.59)
          ..lineTo(0, h * 0.59)
          ..close();
        canvas
          ..drawPath(farDune, Paint()..color = const Color(0x66D89A56))
          ..drawPath(nearDune, Paint()..color = const Color(0x66F0C274));
      case IslandLandscape.forest:
        for (var index = 0; index < 11; index++) {
          final x = w * (index / 10);
          final baseY = h * (0.32 + (index.isEven ? 0.02 : -0.015));
          final treeWidth = w * (index.isEven ? 0.07 : 0.055);
          final treeHeight = h * (index.isEven ? 0.22 : 0.16);
          final tree = Path()
            ..moveTo(x, baseY - treeHeight)
            ..lineTo(x + treeWidth / 2, baseY)
            ..lineTo(x - treeWidth / 2, baseY)
            ..close();
          canvas.drawPath(
            tree,
            Paint()
              ..color = index.isEven
                  ? const Color(0xFF468568)
                  : const Color(0xFF639C70),
          );
        }
      case IslandLandscape.snowyMountains:
        _drawMountain(
          canvas,
          size,
          Offset(w * 0.19, h * 0.4),
          w * 0.38,
          h * 0.42,
          const Color(0xFF7593B0),
        );
        _drawMountain(
          canvas,
          size,
          Offset(w * 0.52, h * 0.38),
          w * 0.46,
          h * 0.5,
          const Color(0xFF91A9C0),
        );
        _drawMountain(
          canvas,
          size,
          Offset(w * 0.89, h * 0.4),
          w * 0.34,
          h * 0.39,
          const Color(0xFF6D88A2),
        );
        for (var index = 0; index < 18; index++) {
          final x = w * ((index * 37 % 97) / 97);
          final y = h * (0.08 + (index * 19 % 65) / 100);
          canvas.drawCircle(
            Offset(x, y),
            math.max(1.0, math.min(w, h) * 0.003),
            Paint()..color = const Color(0xCCFFFFFF),
          );
        }
      case IslandLandscape.volcano:
        final volcano = Path()
          ..moveTo(w * 0.25, h * 0.43)
          ..lineTo(w * 0.47, h * 0.1)
          ..lineTo(w * 0.53, h * 0.1)
          ..lineTo(w * 0.77, h * 0.43)
          ..close();
        final lava = Path()
          ..moveTo(w * 0.47, h * 0.13)
          ..lineTo(w * 0.43, h * 0.27)
          ..lineTo(w * 0.49, h * 0.34)
          ..lineTo(w * 0.48, h * 0.43)
          ..lineTo(w * 0.55, h * 0.43)
          ..lineTo(w * 0.52, h * 0.32)
          ..lineTo(w * 0.57, h * 0.24)
          ..lineTo(w * 0.53, h * 0.13)
          ..close();
        canvas
          ..drawPath(volcano, Paint()..color = const Color(0xFF483D4B))
          ..drawPath(lava, Paint()..color = const Color(0xFFFF713D));
        for (var index = 0; index < 3; index++) {
          canvas.drawCircle(
            Offset(w * (0.47 + index * 0.035), h * (0.08 - index * 0.015)),
            math.min(w, h) * (0.025 + index * 0.006),
            Paint()..color = const Color(0x558B7B83),
          );
        }
        for (var index = 0; index < 9; index++) {
          final x = w * (0.08 + index * 0.1);
          final y = h * (0.12 + (index % 3) * 0.045);
          canvas.drawCircle(
            Offset(x, y),
            math.max(1.5, w * 0.004),
            Paint()..color = const Color(0x77FFE0A0),
          );
        }
    }
  }

  void _drawMountain(
    Canvas canvas,
    Size size,
    Offset center,
    double width,
    double height,
    Color color,
  ) {
    final baseY = center.dy + height * 0.46;
    final peak = Offset(center.dx, center.dy - height * 0.54);
    final left = Offset(center.dx - width / 2, baseY);
    final right = Offset(center.dx + width / 2, baseY);
    final mountain = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(peak.dx, peak.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    final snowcap = Path()
      ..moveTo(peak.dx, peak.dy)
      ..lineTo(peak.dx - width * 0.16, peak.dy + height * 0.24)
      ..lineTo(peak.dx - width * 0.05, peak.dy + height * 0.19)
      ..lineTo(peak.dx + width * 0.02, peak.dy + height * 0.29)
      ..lineTo(peak.dx + width * 0.1, peak.dy + height * 0.19)
      ..lineTo(peak.dx + width * 0.19, peak.dy + height * 0.27)
      ..close();
    canvas
      ..drawPath(mountain, Paint()..color = color)
      ..drawPath(snowcap, Paint()..color = const Color(0xFFF2F7F9));
  }

  void _drawLandscapeFeatures(
    Canvas canvas,
    Size size,
    _IslandPalette palette,
  ) {
    final unit = math.min(size.width, size.height) * 0.04;
    switch (game.landscape) {
      case IslandLandscape.desert:
        for (final x in [size.width * 0.105, size.width * 0.895]) {
          final baseY = size.height * 0.39;
          canvas.drawRect(
            Rect.fromLTWH(
              x - unit * 0.12,
              baseY - unit * 1.2,
              unit * 0.24,
              unit * 1.35,
            ),
            Paint()..color = const Color(0xFF3D9A69),
          );
          canvas.drawRect(
            Rect.fromLTWH(
              x - unit * 0.42,
              baseY - unit * 0.85,
              unit * 0.3,
              unit * 0.2,
            ),
            Paint()..color = const Color(0xFF3D9A69),
          );
          canvas.drawRect(
            Rect.fromLTWH(
              x - unit * 0.42,
              baseY - unit * 0.85,
              unit * 0.2,
              unit * 0.55,
            ),
            Paint()..color = const Color(0xFF3D9A69),
          );
          canvas.drawRect(
            Rect.fromLTWH(
              x + unit * 0.12,
              baseY - unit * 0.55,
              unit * 0.3,
              unit * 0.2,
            ),
            Paint()..color = const Color(0xFF4CAF70),
          );
          canvas.drawRect(
            Rect.fromLTWH(
              x + unit * 0.22,
              baseY - unit * 0.55,
              unit * 0.2,
              unit * 0.42,
            ),
            Paint()..color = const Color(0xFF4CAF70),
          );
        }
      case IslandLandscape.forest:
        for (final x in [size.width * 0.105, size.width * 0.895]) {
          final baseY = size.height * 0.41;
          _drawCube(
            canvas,
            Offset(x, baseY),
            unit * 0.28,
            unit * 0.75,
            const Color(0xFF8A5E3E),
          );
          _drawCube(
            canvas,
            Offset(x, baseY - unit * 0.42),
            unit * 1.12,
            unit * 1.08,
            const Color(0xFF328653),
          );
          _drawCube(
            canvas,
            Offset(x - unit * 0.22, baseY - unit * 0.84),
            unit * 0.62,
            unit * 0.62,
            const Color(0xFF4FA568),
          );
        }
      case IslandLandscape.snowyMountains:
        for (final x in [size.width * 0.105, size.width * 0.895]) {
          final baseY = size.height * 0.405;
          final pine = Path()
            ..moveTo(x, baseY - unit * 1.5)
            ..lineTo(x + unit * 0.55, baseY)
            ..lineTo(x - unit * 0.55, baseY)
            ..close();
          canvas.drawPath(pine, Paint()..color = const Color(0xFF315D58));
          canvas.drawCircle(
            Offset(x, baseY - unit * 1.42),
            unit * 0.12,
            Paint()..color = const Color(0xFFEAF7FC),
          );
        }
      case IslandLandscape.volcano:
        for (final x in [size.width * 0.12, size.width * 0.88]) {
          _drawCube(
            canvas,
            Offset(x, size.height * 0.405),
            unit * 1.15,
            unit * 0.65,
            const Color(0xFF51424A),
          );
          canvas.drawRect(
            Rect.fromLTWH(
              x - unit * 0.12,
              size.height * 0.395,
              unit * 0.24,
              unit * 0.48,
            ),
            Paint()..color = const Color(0xFFFF713D),
          );
        }
    }
  }

  void _drawIsland(Canvas canvas, Size size, _IslandPalette palette) {
    final w = size.width;
    final h = size.height;
    final north = Offset(w * 0.5, h * 0.2);
    final east = Offset(w * 0.98, h * 0.43);
    final south = Offset(w * 0.5, h * 0.65);
    final west = Offset(w * 0.02, h * 0.43);
    final depth = Offset(0, h * 0.115);

    final leftSide = Path()
      ..moveTo(north.dx, north.dy)
      ..lineTo(west.dx, west.dy)
      ..lineTo(west.dx + depth.dx, west.dy + depth.dy)
      ..lineTo(north.dx, north.dy + depth.dy)
      ..close();
    final frontSide = Path()
      ..moveTo(west.dx, west.dy)
      ..lineTo(south.dx, south.dy)
      ..lineTo(east.dx, east.dy)
      ..lineTo(east.dx + depth.dx, east.dy + depth.dy)
      ..lineTo(south.dx, south.dy + depth.dy)
      ..lineTo(west.dx, west.dy + depth.dy)
      ..close();
    canvas.drawPath(leftSide, Paint()..color = palette.leftSide);
    canvas.drawPath(frontSide, Paint()..color = palette.frontSide);

    final top = Path()
      ..moveTo(north.dx, north.dy)
      ..lineTo(east.dx, east.dy)
      ..lineTo(south.dx, south.dy)
      ..lineTo(west.dx, west.dy)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.terrain,
        ).createShader(Rect.fromPoints(north, south)),
    );

    final gridPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    for (var i = 1; i < 7; i++) {
      final t = i / 7;
      canvas.drawLine(
        Offset(w * (0.5 - 0.48 * t), h * (0.2 + 0.23 * t)),
        Offset(w * (0.5 + 0.48 * t), h * (0.2 + 0.23 * t)),
        gridPaint,
      );
    }
  }

  void _drawCube(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Color color,
  ) {
    final halfWidth = width / 2;
    final halfHeight = height / 2;
    final depth = height * 0.42;
    final top = Path()
      ..moveTo(center.dx, center.dy - halfHeight - depth)
      ..lineTo(center.dx + halfWidth, center.dy - halfHeight)
      ..lineTo(center.dx, center.dy - halfHeight + depth)
      ..lineTo(center.dx - halfWidth, center.dy - halfHeight)
      ..close();
    final left = Path()
      ..moveTo(center.dx - halfWidth, center.dy - halfHeight)
      ..lineTo(center.dx, center.dy - halfHeight + depth)
      ..lineTo(center.dx, center.dy + halfHeight + depth)
      ..lineTo(center.dx - halfWidth, center.dy + halfHeight)
      ..close();
    final right = Path()
      ..moveTo(center.dx, center.dy - halfHeight + depth)
      ..lineTo(center.dx + halfWidth, center.dy - halfHeight)
      ..lineTo(center.dx + halfWidth, center.dy + halfHeight)
      ..lineTo(center.dx, center.dy + halfHeight + depth)
      ..close();
    canvas
      ..drawPath(left, Paint()..color = Color.lerp(color, Colors.black, 0.2)!)
      ..drawPath(right, Paint()..color = Color.lerp(color, Colors.black, 0.34)!)
      ..drawPath(top, Paint()..color = Color.lerp(color, Colors.white, 0.18)!);
  }

  void _drawPieceStand(Canvas canvas, Size size, _IslandPalette palette) {
    final y = size.height * 0.81;
    final bounds = Rect.fromLTRB(
      size.width * 0.06,
      y - size.height * 0.045,
      size.width * 0.94,
      y + size.height * 0.045,
    );
    final top = Path()
      ..moveTo(bounds.center.dx, bounds.top)
      ..lineTo(bounds.right, bounds.center.dy)
      ..lineTo(bounds.center.dx, bounds.bottom)
      ..lineTo(bounds.left, bounds.center.dy)
      ..close();
    final side = Path()
      ..moveTo(bounds.left, bounds.center.dy)
      ..lineTo(bounds.center.dx, bounds.bottom)
      ..lineTo(bounds.right, bounds.center.dy)
      ..lineTo(bounds.right, bounds.center.dy + size.height * 0.035)
      ..lineTo(bounds.center.dx, bounds.bottom + size.height * 0.035)
      ..lineTo(bounds.left, bounds.center.dy + size.height * 0.035)
      ..close();
    canvas
      ..drawPath(side, Paint()..color = palette.standSide)
      ..drawPath(top, Paint()..color = palette.standTop);
  }

  void _drawTargets(Canvas canvas, Size size) {
    for (var index = 0; index < game.targets.length; index++) {
      final shape = game.targets[index];
      final center = _point(size, targetPositions[index]);
      final color = Color(shape.colorValue);
      final diameter = math.min(size.width * 0.105, size.height * 0.095);

      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, diameter * 0.33),
          width: diameter * 1.48,
          height: diameter * 0.56,
        ),
        Paint()..color = const Color(0x44704732),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, diameter * 0.2),
          width: diameter * 1.48,
          height: diameter * 0.56,
        ),
        Paint()..color = _IslandPalette.forLandscape(game.landscape).targetBase,
      );
      _drawShape(
        canvas,
        shape,
        center.translate(0, -diameter * 0.04),
        diameter * 0.72,
        color.withValues(alpha: game.isMatched(shape) ? 1 : 0.82),
        filled: game.isMatched(shape),
      );
    }
  }

  void _drawPieces(Canvas canvas, Size size) {
    for (var index = 0; index < game.pieces.length; index++) {
      final shape = game.pieces[index];
      if (game.isMatched(shape) || shape == heldPiece) continue;
      final center = _point(size, piecePositions[index]);
      _drawPiece(canvas, shape, center, size);
    }
    if (heldPiece != null) {
      _drawPiece(
        canvas,
        heldPiece!,
        _point(size, handPosition),
        size,
        lifted: true,
      );
    }
  }

  void _drawPiece(
    Canvas canvas,
    GeometricShape shape,
    Offset center,
    Size size, {
    bool lifted = false,
  }) {
    final diameter = math.min(size.width * 0.1, size.height * 0.1);
    final base = center.translate(0, lifted ? -diameter * 0.1 : 0);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, diameter * 0.25),
        width: diameter * 1.55,
        height: diameter * 0.6,
      ),
      Paint()..color = const Color(0x44704732),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, diameter * 0.13),
        width: diameter * 1.55,
        height: diameter * 0.6,
      ),
      Paint()..color = const Color(0xFFE8CB91),
    );
    _drawShape(
      canvas,
      shape,
      base.translate(0, lifted ? -diameter * 0.34 : -diameter * 0.13),
      diameter * (lifted ? 0.94 : 0.82),
      Color(shape.colorValue),
      filled: true,
    );
  }

  void _drawGuidanceArrow(Canvas canvas, Size size) {
    GeometricShape? indicatedPiece = heldPiece;
    if (indicatedPiece == null) {
      for (final piece in game.pieces) {
        if (!game.isMatched(piece)) {
          indicatedPiece = piece;
          break;
        }
      }
    }
    if (indicatedPiece == null) return;

    final targetIndex = game.targets.indexOf(indicatedPiece);
    if (targetIndex < 0 || game.isMatched(indicatedPiece)) return;
    final target = _point(size, targetPositions[targetIndex]);
    final color = Color(indicatedPiece.colorValue);
    final arrowCenter = target.translate(0, -size.height * 0.1);
    final shaftWidth = math.min(size.width * 0.025, 12.0);
    final shaftHeight = math.min(size.height * 0.045, 20.0);
    final arrow = Path()
      ..moveTo(arrowCenter.dx, arrowCenter.dy + shaftHeight * 0.6)
      ..lineTo(arrowCenter.dx + shaftWidth * 0.35, arrowCenter.dy)
      ..lineTo(arrowCenter.dx + shaftWidth * 0.13, arrowCenter.dy)
      ..lineTo(arrowCenter.dx + shaftWidth * 0.13, arrowCenter.dy - shaftHeight)
      ..lineTo(arrowCenter.dx - shaftWidth * 0.13, arrowCenter.dy - shaftHeight)
      ..lineTo(arrowCenter.dx - shaftWidth * 0.13, arrowCenter.dy)
      ..lineTo(arrowCenter.dx - shaftWidth * 0.35, arrowCenter.dy)
      ..close();
    canvas
      ..drawPath(
        arrow.shift(Offset(0, 4)),
        Paint()..color = const Color(0x6652381D),
      )
      ..drawPath(arrow, Paint()..color = color)
      ..drawPath(
        arrow,
        Paint()
          ..color = const Color(0xFFFFF2B2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  void _drawShape(
    Canvas canvas,
    GeometricShape shape,
    Offset center,
    double size,
    Color color, {
    required bool filled,
  }) {
    final bounds = Rect.fromCenter(center: center, width: size, height: size);
    final path = Path();
    switch (shape) {
      case GeometricShape.circle:
        path.addOval(bounds);
      case GeometricShape.square:
        path.addRect(bounds);
      case GeometricShape.triangle:
        path
          ..moveTo(bounds.center.dx, bounds.top)
          ..lineTo(bounds.right, bounds.bottom)
          ..lineTo(bounds.left, bounds.bottom)
          ..close();
      case GeometricShape.diamond:
        path
          ..moveTo(bounds.center.dx, bounds.top)
          ..lineTo(bounds.right, bounds.center.dy)
          ..lineTo(bounds.center.dx, bounds.bottom)
          ..lineTo(bounds.left, bounds.center.dy)
          ..close();
    }
    if (filled) {
      canvas.drawPath(
        path.shift(Offset(0, size * 0.13)),
        Paint()..color = Color.lerp(color, Colors.black, 0.42)!,
      );
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: filled ? 0.38 : 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_VoxelIslandPainter oldDelegate) => true;
}

class _IslandPalette {
  const _IslandPalette({
    required this.sky,
    required this.sun,
    required this.cloud,
    required this.leftSide,
    required this.frontSide,
    required this.terrain,
    required this.grid,
    required this.standTop,
    required this.standSide,
    required this.targetBase,
  });

  final List<Color> sky;
  final Color sun;
  final Color cloud;
  final Color leftSide;
  final Color frontSide;
  final List<Color> terrain;
  final Color grid;
  final Color standTop;
  final Color standSide;
  final Color targetBase;

  static _IslandPalette forLandscape(IslandLandscape landscape) {
    switch (landscape) {
      case IslandLandscape.desert:
        return const _IslandPalette(
          sky: [Color(0xFF75BCE2), Color(0xFFF6D69B), Color(0xFFE7AC68)],
          sun: Color(0xFFFFF0B0),
          cloud: Color(0xFFFFF0D8),
          leftSide: Color(0xFFAA713D),
          frontSide: Color(0xFF79503C),
          terrain: [Color(0xFFE4C07A), Color(0xFFC99B58)],
          grid: Color(0x55FFF0BB),
          standTop: Color(0xFFD8B77A),
          standSide: Color(0xFF77513D),
          targetBase: Color(0xFFB98D5C),
        );
      case IslandLandscape.forest:
        return const _IslandPalette(
          sky: [Color(0xFF6EB9D5), Color(0xFFB7DFCA), Color(0xFF7BB78B)],
          sun: Color(0xFFFFE6A1),
          cloud: Color(0xFFE9F8FA),
          leftSide: Color(0xFF76513F),
          frontSide: Color(0xFF503B37),
          terrain: [Color(0xFF75C86C), Color(0xFF328653)],
          grid: Color(0x337CE08D),
          standTop: Color(0xFFB9915F),
          standSide: Color(0xFF684631),
          targetBase: Color(0xFF98704B),
        );
      case IslandLandscape.snowyMountains:
        return const _IslandPalette(
          sky: [Color(0xFF579BC7), Color(0xFFB8DBEA), Color(0xFFEAF4F6)],
          sun: Color(0xFFFFF6D0),
          cloud: Color(0xFFF4FAFC),
          leftSide: Color(0xFF60798C),
          frontSide: Color(0xFF42586C),
          terrain: [Color(0xFFF4FAFC), Color(0xFFB8D5E4)],
          grid: Color(0x665D8AA3),
          standTop: Color(0xFFE4F2F7),
          standSide: Color(0xFF7D9CAE),
          targetBase: Color(0xFFA8C5D2),
        );
      case IslandLandscape.volcano:
        return const _IslandPalette(
          sky: [Color(0xFF301F38), Color(0xFF663C48), Color(0xFFAB5845)],
          sun: Color(0xFFFFA45E),
          cloud: Color(0xFFB79FA0),
          leftSide: Color(0xFF59464D),
          frontSide: Color(0xFF382E36),
          terrain: [Color(0xFF686067), Color(0xFF403A43)],
          grid: Color(0x55FF8A4F),
          standTop: Color(0xFF8A7469),
          standSide: Color(0xFF51424A),
          targetBase: Color(0xFF66544F),
        );
    }
  }
}
