import 'dart:ui';

import 'package:flutter/material.dart';

/// A clipped material for floating controls. Blur stays inside this surface.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final double? opacity;
  final Color? tintColor;
  final Color? borderColor;

  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
    this.elevated = true,
    this.opacity,
    this.tintColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final surfaceOpacity = highContrast ? 1.0 : opacity ?? .97;
    final tint = tintColor ??
        (dark ? const Color(0xFF211E20) : const Color(0xFFFFFCF9));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated ? [
          BoxShadow(color: Colors.black.withValues(alpha: dark ? .22 : .06), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 4, offset: const Offset(0, 2)),
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          enabled: !highContrast && surfaceOpacity < .9,
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint.withValues(alpha: surfaceOpacity),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color:
                    borderColor ?? Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
              gradient: highContrast ? null : LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: dark ? .09 : .38), Colors.white.withValues(alpha: 0)],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const GlassIconButton({super.key, required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 16,
      elevated: false,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}

/// Keeps checkout actions within the safe area, in the same floating material.
class GlassActionBar extends StatelessWidget {
  final Widget child;
  const GlassActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(14, 8, 14, 10),
    child: GlassSurface(
      radius: 26,
      padding: const EdgeInsets.all(14),
      child: child,
    ),
  );
}
