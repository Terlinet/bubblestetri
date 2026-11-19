import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'tetris_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF080512),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TerlineTBubblesChainApp());
}

class TerlineTBubblesChainApp extends StatelessWidget {
  const TerlineTBubblesChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerlineT BubblesChain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080512),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F5FF),
          secondary: Color(0xFFFF2BD6),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _clips = [
    'assets/videos/TerlineT_Video_1795029283383.webm',
    'assets/videos/TerlineT_Video_1795029442732.webm',
    'assets/videos/TerlineT_Video_1795029610645.webm',
    'assets/videos/TerlineT_Video_1795029727439.webm',
  ];
  static const _clipLinks = [
    'https://terlinet.github.io/terlinetscreen/',
    'https://terlinet.github.io/terlinet_it_manager/',
    'https://terlinet.github.io/counter/',
    'https://terlinet.github.io/governance/',
  ];

  late final AnimationController _motion;
  VideoPlayerController? _video;
  String? _videoError;
  final List<_Bubble> _bubbles = _createBubbles();

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.asset(
      'assets/videos/BubblesChain.mp4',
    );
    _video = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() {});
    } catch (error, stackTrace) {
      debugPrint('Could not start the home background video: $error');
      debugPrintStack(stackTrace: stackTrace);
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _video = null;
        _videoError = 'VIDEO FEED OFFLINE';
      });
    }
  }

  Future<void> _openPumpProfile() async {
    final uri = Uri.parse('https://pump.fun/profile/bubbleschain?share');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o perfil no Pump.fun.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _openUsefulLinks() {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          _UsefulLinksDialog(assets: _clips, onOpenLink: _openClipLink),
    );
  }

  Future<void> _openClipLink(int index) async {
    try {
      final opened = await launchUrl(Uri.parse(_clipLinks[index]));
      if (!opened && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir o site deste vídeo.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (error, stackTrace) {
      debugPrint('Could not open site for clip ${index + 1}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir o site deste vídeo.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF080512)),
          if (video != null && video.value.isInitialized)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: video.value.size.width,
                  height: video.value.size.height,
                  child: VideoPlayer(video),
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xC9080512),
                  Color(0x80080512),
                  Color(0xD9080512),
                ],
              ),
            ),
          ),
          CustomPaint(
            painter: _NeonOrbitPainter(motion: _motion, bubbles: _bubbles),
            child: const SizedBox.expand(),
          ),
          Center(child: _buildTitle()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                children: [
                  _buildTopHud(),
                  const Spacer(),
                  _buildMenuButtons(),
                  const SizedBox(height: 22),
                  _buildBottomHud(),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: Semantics(
                button: true,
                label: 'Abrir perfil BubblesChain no Pump.fun',
                child: Tooltip(
                  message: 'Abrir perfil no Pump.fun',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openPumpProfile,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.35, -0.45),
                            radius: 0.95,
                            colors: [
                              Color(0xFFFFFFFF),
                              Color(0xCC00F5FF),
                              Color(0xCC743DFF),
                              Color(0xCCFF2BD6),
                            ],
                            stops: [0, 0.18, 0.58, 1],
                          ),
                          border: Border.all(
                            color: const Color(0xCCB9FFFF),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F5FF)
                                  .withValues(alpha: 0.48),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.currency_exchange_rounded,
                              size: 20,
                              color: Color(0xFF080512),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'PUMP',
                              style: TextStyle(
                                color: Color(0xFF080512),
                                fontFamily: 'monospace',
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 52,
            child: SafeArea(
              child: Image.asset(
                'assets/videos/pengu-pudgy.gif',
                width: 84,
                height: 84,
                fit: BoxFit.contain,
                semanticLabel: 'Pinguim animado',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: const Offset(3, 0),
              child: _titleText(const Color(0xFFFF2BD6).withValues(alpha: 0.8)),
            ),
            Transform.translate(
              offset: const Offset(-3, 0),
              child: _titleText(const Color(0xFF00F5FF).withValues(alpha: 0.8)),
            ),
            _titleText(const Color(0xFFF7FBFF)),
          ],
        ),
      ),
    );
  }

  Widget _titleText(Color color) {
    final style = TextStyle(
      color: color,
      fontFamily: 'monospace',
      fontSize: 54,
      fontWeight: FontWeight.bold,
      letterSpacing: 13,
      height: 1.1,
      shadows: [
        Shadow(color: const Color(0xFF00F5FF), blurRadius: 18),
        Shadow(color: const Color(0xFFFF2BD6), blurRadius: 34),
      ],
    );
    final middleWidth = TextPainter(
      text: TextSpan(text: 'erline', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    const endLetterGap = 16.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('T', style: style.copyWith(fontSize: 68)),
        const SizedBox(width: endLetterGap),
        SizedBox(
          width: middleWidth.width,
          child: Center(child: Text('erline', style: style)),
        ),
        const SizedBox(width: endLetterGap),
        Text('T', style: style.copyWith(fontSize: 68)),
      ],
    );
  }

  Widget _buildTopHud() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF00F5FF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F5FF).withValues(alpha: 0.8),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'TERLINET  //  NEON ARCADE',
          style: TextStyle(
            color: Color(0xFFD8FBFF),
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        const Spacer(),
        const Icon(Icons.waves_rounded, color: Color(0xFFFF2BD6), size: 19),
      ],
    );
  }

  Widget _buildMenuButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 14,
      children: [
        _buildBubbleButton(
          label: 'JOGAR',
          semanticLabel: 'Iniciar jogo',
          icon: Icons.play_arrow_rounded,
          colors: const [
            Color(0xBFFFFFFF),
            Color(0xCC00F5FF),
            Color(0xCC743DFF),
            Color(0xCCFF2BD6),
          ],
          message: 'Abrindo Bubbles Tetris.',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const TetrisScreen(),
              ),
            );
          },
        ),
        _buildBubbleButton(
          label: 'APRENDER',
          semanticLabel: 'Aprender a jogar',
          icon: Icons.school_rounded,
          colors: const [
            Color(0xBFFFFFFF),
            Color(0xCCB05CFF),
            Color(0xCC743DFF),
            Color(0xCC00F5FF),
          ],
          message: 'As opções de aprendizado serão adicionadas em breve.',
        ),
        _buildBubbleButton(
          label: 'INTERAGIR',
          semanticLabel: 'Interagir',
          icon: Icons.touch_app_rounded,
          colors: const [
            Color(0xBFFFFFFF),
            Color(0xCCFFB547),
            Color(0xCCFF2BD6),
            Color(0xCC743DFF),
          ],
          message: 'As opções de interação serão adicionadas em breve.',
        ),
        _buildBubbleButton(
          label: 'LINKS ÚTEIS',
          semanticLabel: 'Abrir links úteis',
          icon: Icons.link_rounded,
          colors: const [
            Color(0xBFFFFFFF),
            Color(0xCC00F5FF),
            Color(0xCC743DFF),
            Color(0xCCFF2BD6),
          ],
          message: 'Abrindo links úteis.',
          onPressed: _openUsefulLinks,
        ),
      ],
    );
  }

  Widget _buildBubbleButton({
    required String label,
    required String semanticLabel,
    required IconData icon,
    required List<Color> colors,
    required String message,
    VoidCallback? onPressed,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap:
              onPressed ??
              () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(message),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
              },
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.55),
                radius: 0.95,
                colors: colors,
                stops: const [0, 0.16, 0.62, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F5FF).withValues(alpha: 0.42),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFFFF2BD6).withValues(alpha: 0.32),
                  blurRadius: 36,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 14,
                  left: 23,
                  child: Container(
                    width: 22,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.55),
                          blurRadius: 9,
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 31,
                      shadows: const [
                        Shadow(color: Color(0xFF00F5FF), blurRadius: 12),
                      ],
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        shadows: [
                          Shadow(color: Color(0xFFFF2BD6), blurRadius: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomHud() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFF00F5FF).withValues(alpha: 0.7),
                const Color(0xFFFF2BD6).withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _videoError ?? 'BUBBLES CHAIN  //  SYSTEM ONLINE',
          style: TextStyle(
            color: _videoError == null
                ? const Color(0xFFC1AEE8)
                : const Color(0xFFFF6B86),
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1.7,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _UsefulLinksDialog extends StatefulWidget {
  const _UsefulLinksDialog({required this.assets, required this.onOpenLink});

  final List<String> assets;
  final Future<void> Function(int index) onOpenLink;

  @override
  State<_UsefulLinksDialog> createState() => _UsefulLinksDialogState();
}

class _UsefulLinksDialogState extends State<_UsefulLinksDialog> {
  late final List<VideoPlayerController> _controllers;
  late final List<bool> _errors;

  @override
  void initState() {
    super.initState();
    _errors = List<bool>.filled(widget.assets.length, false);
    _controllers = widget.assets
        .map((asset) => VideoPlayerController.asset(asset))
        .toList();

    for (var index = 0; index < _controllers.length; index++) {
      _initializeClip(index);
    }
  }

  Future<void> _initializeClip(int index) async {
    final controller = _controllers[index];

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() {});
    } catch (error, stackTrace) {
      debugPrint('Could not start useful link clip ${index + 1}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _errors[index] = true;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width - 32, 900.0);
    final height = math.min(screenSize.height - 32, 720.0);

    return Dialog(
      backgroundColor: const Color(0xFF100A20),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0x9900F5FF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'LINKS ÚTEIS',
                    style: TextStyle(
                      color: Color(0xFF00F5FF),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Fechar links úteis',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  itemCount: _controllers.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 16 / 9,
                  ),
                  itemBuilder: (context, index) {
                    final controller = _controllers[index];

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Material(
                        color: const Color(0xFF080512),
                        child: InkWell(
                          onTap: () => widget.onOpenLink(index),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_errors[index])
                                const Center(
                                  child: Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFFF6B86),
                                  ),
                                )
                              else if (controller.value.isInitialized)
                                FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: controller.value.size.width,
                                    height: controller.value.size.height,
                                    child: IgnorePointer(
                                      child: VideoPlayer(controller),
                                    ),
                                  ),
                                )
                              else
                                const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00F5FF),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble {
  const _Bubble({
    required this.phase,
    required this.direction,
    required this.speed,
    required this.orbitX,
    required this.orbitY,
    required this.radius,
    required this.color,
  });

  final double phase;
  final double direction;
  final double speed;
  final double orbitX;
  final double orbitY;
  final double radius;
  final Color color;
}

List<_Bubble> _createBubbles() {
  final random = math.Random(47);
  const colors = [Color(0xFF00F5FF), Color(0xFFFF2BD6), Color(0xFFB05CFF)];

  return List.generate(30, (index) {
    return _Bubble(
      phase: random.nextDouble() * math.pi * 2,
      direction: random.nextBool() ? 1 : -1,
      speed: 0.18 + random.nextDouble() * 0.28,
      orbitX: 0.42 + random.nextDouble() * 0.58,
      orbitY: 0.48 + random.nextDouble() * 0.52,
      radius: 3 + random.nextDouble() * 8,
      color: colors[index % colors.length],
    );
  });
}

class _NeonOrbitPainter extends CustomPainter {
  _NeonOrbitPainter({required this.motion, required this.bubbles})
    : super(repaint: motion);

  final Animation<double> motion;
  final List<_Bubble> bubbles;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final time = motion.value * 2 * math.pi;
    final orbitLimitX = math.min(size.width * 0.47, 300.0);
    final orbitLimitY = math.min(size.height * 0.36, 310.0);

    _drawGrid(canvas, size);
    _drawOrbit(canvas, center, orbitLimitX, orbitLimitY, 0.76, 0.12);
    _drawOrbit(canvas, center, orbitLimitX, orbitLimitY, 1, 0.2);

    for (final bubble in bubbles) {
      final angle = bubble.phase + time * bubble.speed * bubble.direction;
      final breathe = 1 + math.sin(time * 1.4 + bubble.phase) * 0.045;
      final x =
          center.dx + math.cos(angle) * orbitLimitX * bubble.orbitX * breathe;
      final y =
          center.dy + math.sin(angle) * orbitLimitY * bubble.orbitY * breathe;
      _drawBubble(canvas, Offset(x, y), bubble.radius, bubble.color);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: 0.055)
      ..strokeWidth = 0.6;

    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawOrbit(
    Canvas canvas,
    Offset center,
    double radiusX,
    double radiusY,
    double scale,
    double opacity,
  ) {
    final rect = Rect.fromCenter(
      center: center,
      width: radiusX * 2 * scale,
      height: radiusY * 2 * scale,
    );
    final paint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawOval(rect, paint);
  }

  void _drawBubble(Canvas canvas, Offset center, double radius, Color color) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawCircle(center, radius * 1.35, glowPaint);

    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.48),
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0.035),
        ],
        stops: const [0, 0.22, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, fillPaint);

    final outlinePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawCircle(center, radius, outlinePaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + Offset(-radius * 0.35, -radius * 0.42),
      center + Offset(radius * 0.02, -radius * 0.55),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonOrbitPainter oldDelegate) =>
      oldDelegate.bubbles != bubbles || oldDelegate.motion != motion;
}
