import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'hand_tracking.dart';

class GestureNavigationOverlay extends StatefulWidget {
  const GestureNavigationOverlay({
    required this.child,
    this.onRepeatIntroduction,
    super.key,
  });

  final Widget child;
  final Future<void> Function()? onRepeatIntroduction;

  @override
  State<GestureNavigationOverlay> createState() =>
      _GestureNavigationOverlayState();
}

class GestureNavigationScope extends InheritedWidget {
  const GestureNavigationScope({
    required this.onRepeatIntroduction,
    required super.child,
    super.key,
  });

  final Future<void> Function()? onRepeatIntroduction;

  static GestureNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GestureNavigationScope>();

  @override
  bool updateShouldNotify(GestureNavigationScope oldWidget) =>
      oldWidget.onRepeatIntroduction != onRepeatIntroduction;
}

class _GestureNavigationOverlayState extends State<GestureNavigationOverlay> {
  final HandTrackingService _tracking = HandTrackingService.instance;
  Offset? _cursor;
  bool _isPinching = false;
  int _nextPointer = 1000;

  @override
  void initState() {
    super.initState();
    _tracking.pose.addListener(_onPose);
  }

  void _onPose() {
    final pose = _tracking.pose.value;
    if (pose == null) {
      _isPinching = false;
      if (_cursor != null && mounted) setState(() => _cursor = null);
      return;
    }

    final position = Offset(pose.x, pose.y);
    final clickStarted = pose.isPoking || (pose.isPinching && !_isPinching);
    _isPinching = pose.isPinching;
    if (mounted) setState(() => _cursor = position);
    if (clickStarted && _tracking.isActive.value) {
      _dispatchTap(position);
    }
  }

  void _dispatchTap(Offset normalizedPosition) {
    final size = MediaQuery.sizeOf(context);
    final position = Offset(
      normalizedPosition.dx.clamp(0.0, 1.0) * size.width,
      normalizedPosition.dy.clamp(0.0, 1.0) * size.height,
    );
    final pointer = _nextPointer++;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: pointer, position: position),
    );
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(pointer: pointer, position: position),
    );
  }

  @override
  void dispose() {
    _tracking.pose.removeListener(_onPose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureNavigationScope(
          onRepeatIntroduction: widget.onRepeatIntroduction,
          child: widget.child,
        ),
        Positioned(
          left: 0,
          bottom: 0,
          width: 1,
          height: 1,
          child: IgnorePointer(
            child: Opacity(opacity: 0, child: _tracking.buildPreview()),
          ),
        ),
        if (_cursor case final cursor?)
          Positioned(
            left: cursor.dx * screenSize.width - 18,
            top: cursor.dy * screenSize.height - 18,
            child: IgnorePointer(
              child: Container(
                width: 36,
                height: 36,
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
                      color: const Color(0xFF38C9E8).withValues(alpha: 0.6),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(
                  _isPinching
                      ? Icons.front_hand_rounded
                      : Icons.near_me_rounded,
                  size: 20,
                  color: _isPinching ? const Color(0xFFFFCB65) : Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
