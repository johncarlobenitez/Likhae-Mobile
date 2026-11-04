import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion_effects.dart';
import 'motion_preferences.dart';
import 'motion_timeline.dart';

export 'motion_effects.dart' show AppSuccessMark;
export 'motion_preferences.dart';

/// Plays once when mounted. The child is reused on every animation frame.
class AppReveal extends StatelessWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.milliseconds = 280,
    this.beginScale = 0.96,
  });

  final Widget child;
  final int milliseconds;
  final double beginScale;

  @override
  Widget build(BuildContext context) {
    final reduced = appReduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: appMotionDuration(context, milliseconds: milliseconds),
      curve: AppMotion.settle,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: reduced ? 1 : value,
        child: Transform.scale(
          scale: reduced ? 1 : beginScale + (1 - beginScale) * value,
          child: child,
        ),
      ),
    );
  }
}

/// For small, keyed status labels and icons, never whole pages or lists.
class AppStatusSwitcher extends StatelessWidget {
  const AppStatusSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (appReduceMotion(context)) return child;
    return AnimatedSwitcher(
      duration: AppMotion.quick,
      reverseDuration: const Duration(milliseconds: 120),
      switchInCurve: AppMotion.settle,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      // Outgoing status must not remain actionable or be read as current.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [
          for (final child in previous)
            ExcludeSemantics(child: IgnorePointer(child: child)),
          ?current,
        ],
      ),
      child: child,
    );
  }
}

/// Retains the content's element tree during refreshes and theme changes.
class AppDataReveal extends StatelessWidget {
  const AppDataReveal({super.key, required this.ready, required this.child});

  final bool ready;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: ready ? 1 : 0),
    duration: appMotionDuration(context, milliseconds: 180),
    curve: Curves.easeOut,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: !ready || appReduceMotion(context) ? 1 : value,
      alwaysIncludeSemantics: true,
      child: child,
    ),
  );
}

class AppFavoriteIcon extends StatefulWidget {
  const AppFavoriteIcon({
    super.key,
    required this.selected,
    this.loading = false,
    this.size = 23,
    this.color,
  });

  final bool selected;
  final bool loading;
  final double size;
  final Color? color;

  @override
  State<AppFavoriteIcon> createState() => _AppFavoriteIconState();
}

class _AppFavoriteIconState extends State<AppFavoriteIcon> {
  int _selectionRevision = 0;
  bool _pendingSelection = false;
  bool _playSelection = false;

  @override
  void didUpdateWidget(covariant AppFavoriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) _pendingSelection = true;
    if (!widget.selected) {
      _pendingSelection = false;
      _playSelection = false;
    }
    if (!widget.loading && _pendingSelection) {
      _pendingSelection = false;
      _playSelection = true;
      _selectionRevision++;
    }
  }

  @override
  Widget build(BuildContext context) => AppMotionTimeline(
    duration: const Duration(milliseconds: 360),
    play: _playSelection && !widget.loading,
    replayKey: _selectionRevision,
    builder: (context, progress) => AnimatedBuilder(
      animation: progress,
      child: AppStatusSwitcher(
        child: widget.loading
            ? AppLoadingIndicator(
                key: const ValueKey('loading'),
                size: widget.size,
                color: widget.color,
                label: 'Updating wishlist',
              )
            : Icon(
                widget.selected
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(widget.selected),
                size: widget.size,
                color: widget.color ?? Theme.of(context).colorScheme.primary,
              ),
      ),
      builder: (context, child) {
        final p = progress.value;
        // One small overshoot, one settle; never bounces on initial rendering.
        final scale = 1 + 0.18 * math.sin(math.pi * 2 * p) * (1 - p);
        return Transform.scale(scale: scale, child: child);
      },
    ),
  );
}

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 24,
    this.color,
    this.label = 'Loading',
  });

  final double size;
  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: appReduceMotion(context)
            ? Icon(
                Icons.hourglass_top_rounded,
                size: size,
                color: color ?? Theme.of(context).colorScheme.primary,
              )
            : AppActivityRing(
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
      ),
    ),
  );
}

class AppLoadingLine extends StatelessWidget {
  const AppLoadingLine({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: ExcludeSemantics(
      child: appReduceMotion(context)
          ? SizedBox(
              height: 3,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            )
          : const AppActivityLine(),
    ),
  );
}

/// The same uncropped brand mark at both ends of the finite opening timeline.
class AppOpeningContent extends StatefulWidget {
  const AppOpeningContent({super.key, this.closing = false});
  final bool closing;
  @override
  State<AppOpeningContent> createState() => _AppOpeningContentState();
}

class _AppOpeningContentState extends State<AppOpeningContent> {
  // Existing transparent version of the official mark. No generated logo,
  // circular cropping, white JPEG tile, or upscaled launcher bitmap.
  static const _logo = ResizeImage(
    AssetImage('assets/icons/likhae_ai_logo.png'),
    width: 480,
  );
  bool _precached = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheImage(_logo, context, onError: (error, stackTrace) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppMotionTimeline(
      duration: const Duration(milliseconds: 1250),
      builder: (context, progress) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBrandFrame(
            progress: progress,
            child: SizedBox.square(
              dimension: 196,
              child: Center(
                child: Image(
                  image: _logo,
                  width: 154,
                  height: 154,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  color: dark ? colors.primary : null,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => Icon(
                    Icons.handshake_outlined,
                    size: 80,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: progress.drive(
              CurveTween(
                curve: const Interval(0.08, .55, curve: Curves.easeOut),
              ),
            ),
            child: Text(
              'LIKHAE',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.closing
                ? 'Shopping and delivery, connected.'
                : 'SHOP  •  TRACK  •  DELIVER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.closing ? 13 : 11,
              letterSpacing: widget.closing ? 0 : 1.2,
              color: colors.onSurfaceVariant,
            ),
          ),
          if (widget.closing) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final label in ['SHOP', 'TRACK', 'DELIVER'])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 10, color: colors.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: 98,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.outline,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: progress,
                  child: ColoredBox(color: colors.primary),
                  builder: (context, child) => FractionallySizedBox(
                    widthFactor: progress.value,
                    heightFactor: 1,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
