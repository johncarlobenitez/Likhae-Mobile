import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_surface.dart';
import 'motion_preferences.dart';

class GlassNavigationDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final bool prominent;

  const GlassNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.prominent = false,
  });
}

class GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<GlassNavigationDestination> destinations;

  const GlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final duration = appReduceMotion(context)
        ? Duration.zero
        : AppMotion.standard;
    final labelSize = destinations.length > 4 ? 10.0 : 11.0;
    final bool hasProminentDestination = destinations.any(
      (GlassNavigationDestination destination) => destination.prominent,
    );
    final height =
        (hasProminentDestination ? 82.0 : 68.0) +
        (media.textScaler.scale(labelSize) - labelSize).clamp(0.0, 24.0);
    final Color navigationSurfaceTint = dark
        ? const Color(0xFF292225)
        : const Color(0xFFFFF5F1);
    return GlassSurface(
      radius: 36,
      padding: const EdgeInsets.all(6),
      opacity: .76,
      blurSigma: 8,
      tintColor: navigationSurfaceTint,
      borderColor: colors.primary.withValues(alpha: dark ? .38 : .27),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / destinations.length;
            final rtl = Directionality.of(context) == TextDirection.rtl;
            final index = rtl
                ? destinations.length - 1 - currentIndex
                : currentIndex;
            final hasSelectedDestination =
                currentIndex >= 0 && currentIndex < destinations.length;
            return Stack(
              children: [
                if (hasSelectedDestination &&
                    !destinations[currentIndex].prominent)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: index * itemWidth,
                        end: index * itemWidth,
                      ),
                      duration: duration,
                      curve: AppMotion.settle,
                      builder: (context, x, child) => Transform.translate(
                        offset: Offset(x, 0),
                        child: child,
                      ),
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: SizedBox(
                            width: itemWidth,
                            height: height,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(29),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: dark ? .20 : .28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (int i = 0; i < destinations.length; i++)
                      Expanded(
                        child: Semantics(
                          selected: i == currentIndex,
                          button: true,
                          label: destinations[i].label,
                          child: Tooltip(
                            message: destinations[i].label,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () {
                                  if (i == currentIndex) return;
                                  HapticFeedback.selectionClick();
                                  destinations[i].onTap();
                                },
                                child: ExcludeSemantics(
                                  child: SizedBox.expand(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        AnimatedScale(
                                          scale:
                                              i == currentIndex &&
                                                  !destinations[i].prominent
                                              ? 1.06
                                              : 1,
                                          duration: duration,
                                          child: Badge.count(
                                            count: destinations[i].badgeCount,
                                            isLabelVisible:
                                                destinations[i].badgeCount > 0,
                                            child: destinations[i].prominent
                                                ? Container(
                                                    width: 56,
                                                    height: 56,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: colors.primary,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: colors.onPrimary
                                                            .withValues(
                                                              alpha: .24,
                                                            ),
                                                      ),
                                                      boxShadow: <BoxShadow>[
                                                        BoxShadow(
                                                          color: colors.primary
                                                              .withValues(
                                                                alpha: dark
                                                                    ? .32
                                                                    : .22,
                                                              ),
                                                          blurRadius: 12,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      i == currentIndex
                                                          ? destinations[i]
                                                              .selectedIcon
                                                          : destinations[i].icon,
                                                      color: colors.onPrimary,
                                                      size: 28,
                                                    ),
                                                  )
                                                : Icon(
                                                    i == currentIndex
                                                        ? destinations[i]
                                                            .selectedIcon
                                                        : destinations[i].icon,
                                                    color: i == currentIndex
                                                        ? colors.onPrimary
                                                        : colors.onSurface
                                                              .withValues(
                                                                alpha: .60,
                                                              ),
                                                    size: 23,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Text(
                                            destinations[i].label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: labelSize,
                                              fontWeight:
                                                  i == currentIndex ||
                                                      destinations[i].prominent
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color:
                                                  destinations[i].prominent
                                                  ? colors.onSurface.withValues(
                                                      alpha: .70,
                                                    )
                                                  : i == currentIndex
                                                  ? colors.onPrimary
                                                  : colors.onSurface.withValues(
                                                      alpha: .65,
                                                    ),
                                            ),
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
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GlassNavigationFrame extends StatelessWidget {
  final Widget child;
  final Widget navigation;
  const GlassNavigationFrame({
    super.key,
    required this.child,
    required this.navigation,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: media.viewInsets.bottom > 0
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: navigation,
                ),
              ),
            ),
    );
  }
}
