import 'package:flutter/material.dart';

import 'motion_preferences.dart';

/// Owns one clock. Builders attach painters/transitions to [Animation] rather
/// than rebuilding their surrounding screen on each frame.
class AppMotionTimeline extends StatefulWidget {
  const AppMotionTimeline({
    super.key,
    required this.duration,
    required this.builder,
    this.repeat = false,
    this.replayKey,
    this.play = true,
  });

  final Duration duration;
  final Widget Function(BuildContext, Animation<double>) builder;
  final bool repeat;
  final Object? replayKey;
  final bool play;

  @override
  State<AppMotionTimeline> createState() => _AppMotionTimelineState();
}

class _AppMotionTimelineState extends State<AppMotionTimeline>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _visible = true;
  bool _reduced = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _reduced = appReduceMotion(context);
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant AppMotionTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.replayKey != widget.replayKey) {
      _controller.value = 0;
    }
    if (oldWidget.repeat != widget.repeat ||
        oldWidget.duration != widget.duration) {
      _controller.stop();
    }
    _syncPlayback();
  }

  void _syncPlayback() {
    if (_reduced || !widget.play) {
      _controller.value = 1;
    } else if (!_visible || !_foreground) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      if (widget.repeat) {
        _controller.repeat();
      } else if (!_controller.isCompleted) {
        _controller.forward();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
