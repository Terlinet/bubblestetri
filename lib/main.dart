import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'coordenar_screen.dart';
import 'gesture_navigation.dart';
import 'hand_tracking.dart';
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

class TerlineTBubblesChainApp extends StatefulWidget {
  const TerlineTBubblesChainApp({super.key});

  @override
  State<TerlineTBubblesChainApp> createState() =>
      _TerlineTBubblesChainAppState();
}

class _TerlineTBubblesChainAppState extends State<TerlineTBubblesChainApp> {
  final FlutterTts _voice = FlutterTts();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _setScreenAwake(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_announceGestureNavigation());
    });
  }

  late final WidgetsBindingObserver _lifecycleObserver = _AppLifecycleObserver(
    _handleLifecycleChange,
  );

  void _handleLifecycleChange(AppLifecycleState state) {
    _setScreenAwake(state == AppLifecycleState.resumed);
  }

  Future<void> _setScreenAwake(bool awake) async {
    try {
      if (awake) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (error, stackTrace) {
      debugPrint('Could not update screen wakelock: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _announceGestureNavigation() async {
    try {
      await _voice.setLanguage('pt-BR');
    } catch (error, stackTrace) {
      debugPrint('Could not set Portuguese speech: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _voice.setSpeechRate(0.78);
      await _voice.setPitch(1.28);
    } catch (error, stackTrace) {
      debugPrint('Could not configure the voice: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      final voices = await _voice.getVoices;
      if (voices is List) {
        final femaleVoice = voices.cast<dynamic>().firstWhere((voice) {
          if (voice is! Map) return false;
          final name = '${voice['name']}'.toLowerCase();
          final gender = '${voice['gender']}'.toLowerCase();
          final locale = '${voice['locale']}'.toLowerCase();
          return locale.startsWith('pt') &&
              (gender.contains('female') ||
                  name.contains('female') ||
                  name.contains('femin') ||
                  name.contains('francisca') ||
                  name.contains('camila') ||
                  name.contains('luciana') ||
                  name.contains('maria'));
        }, orElse: () => null);
        if (femaleVoice is Map) {
          await _voice.setVoice({
            'name': femaleVoice['name'],
            'locale': femaleVoice['locale'],
          });
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Could not select a Portuguese female voice: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _voice.speak(
        'Olá! Ative os gestos e permita o acesso à câmera. '
        'Depois você poderá usar o aplicativo sem tocar na tela. '
        'Aponte o indicador e empurre para clicar, ou feche a pinça '
        'para clicar, segurar e mover as peças.',
      );
    } catch (error, stackTrace) {
      debugPrint('Could not play the gesture navigation introduction: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    unawaited(_setScreenAwake(false));
    _voice.stop();
    super.dispose();
  }

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
      home: HomeScreen(onRepeatIntroduction: _announceGestureNavigation),
    );
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  _AppLifecycleObserver(this.onStateChanged);

  final ValueChanged<AppLifecycleState> onStateChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.onRepeatIntroduction, super.key});

  final Future<void> Function() onRepeatIntroduction;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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
  late final AnimationController _gesturePulse;
  final HandTrackingService _handTracking = HandTrackingService.instance;
  VideoPlayerController? _video;
  String? _videoError;
  final List<_Bubble> _bubbles = _createBubbles();
  bool _cameraBusy = false;
  bool _cameraActive = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _gesturePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cameraActive = _handTracking.isActive.value;
    if (!_cameraActive) _gesturePulse.repeat(reverse: true);
    _handTracking.isActive.addListener(_syncGestureState);
    _initializeVideo();
  }

  void _syncGestureState() {
    if (mounted) {
      setState(() => _cameraActive = _handTracking.isActive.value);
      if (_cameraActive || _cameraBusy) {
        _gesturePulse
          ..stop()
          ..value = 0;
      } else {
        _gesturePulse.repeat(reverse: true);
      }
    }
  }

  Future<void> _toggleGestures() async {
    if (_cameraBusy || _handTracking.isBusy) return;
    setState(() => _cameraBusy = true);
    _gesturePulse
      ..stop()
      ..value = 0;
    try {
      if (_handTracking.isActive.value) {
        await _handTracking.stop();
      } else {
        await _handTracking.start();
      }
    } catch (error, stackTrace) {
      debugPrint('Could not toggle hand navigation: $error');
      debugPrintStack(stackTrace: stackTrace);
      _handTracking.status.value = error is UnsupportedError
          ? error.message?.toString() ?? 'Gestos disponíveis na versão Web.'
          : 'Câmera indisponível. Verifique a permissão e tente novamente.';
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(_handTracking.status.value),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _cameraBusy = false);
        if (!_cameraActive) _gesturePulse.repeat(reverse: true);
      }
    }
  }

  Future<void> _openGame(Widget game) async {
    try {
      if (_handTracking.isActive.value) {
        await _handTracking.stop();
      }
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (context) => game));
    } catch (error, stackTrace) {
      debugPrint('Could not open game screen: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir o jogo. Tente novamente.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
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
    _gesturePulse.dispose();
    _handTracking.isActive.removeListener(_syncGestureState);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;

    return GestureNavigationOverlay(
      onRepeatIntroduction: widget.onRepeatIntroduction,
      child: Scaffold(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
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
          onPressed: () => _openGame(const TetrisScreen()),
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
          label: 'COORDENAR',
          semanticLabel: 'Jogar Coordenar',
          icon: Icons.touch_app_rounded,
          colors: const [
            Color(0xBFFFFFFF),
            Color(0xCCFFB547),
            Color(0xCCFF2BD6),
            Color(0xCC743DFF),
          ],
          message: 'Abrindo o jogo Coordenar.',
          onPressed: () => _openGame(const CoordenarScreen()),
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
    final repeatIntroduction = widget.onRepeatIntroduction;
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!_cameraActive && !_cameraBusy) ...[
              const Text('👉', style: TextStyle(fontSize: 23)),
              const SizedBox(width: 4),
            ],
            AnimatedBuilder(
              animation: _gesturePulse,
              builder: (context, child) => Transform.scale(
                scale: _cameraActive || _cameraBusy
                    ? 1
                    : 1 + _gesturePulse.value * 0.07,
                child: child,
              ),
              child: _buildGestureToggle(),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: repeatIntroduction,
              tooltip: 'Ouvir instruções novamente',
              icon: const Icon(Icons.volume_up_rounded),
              color: const Color(0xFFBDEBFF),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGestureToggle() {
    final activeColor = _cameraActive
        ? const Color(0xFF71F79F)
        : const Color(0xFFBDEBFF);
    return Semantics(
      button: true,
      label: _cameraActive ? 'Desativar gestos' : 'Ativar gestos',
      child: Tooltip(
        message: _cameraActive ? 'Desativar gestos' : 'Ativar gestos',
        child: Material(
          color: const Color(0xFF171027),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: _cameraBusy ? null : _toggleGestures,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: activeColor.withValues(alpha: 0.85)),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(
                      alpha: _cameraActive ? 0.22 : 0.35,
                    ),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cameraBusy)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: activeColor,
                      ),
                    )
                  else
                    Icon(
                      _cameraActive
                          ? Icons.front_hand_rounded
                          : Icons.front_hand_outlined,
                      size: 19,
                      color: activeColor,
                    ),
                  const SizedBox(width: 7),
                  const Text(
                    'Gestos',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
