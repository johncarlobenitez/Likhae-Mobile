import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_surface.dart';

class GlassNavigationDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const GlassNavigationDestination({required this.icon, required this.selectedIcon, required this.label, required this.onTap, this.badgeCount = 0});
}

class GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<GlassNavigationDestination> destinations;

  const GlassNavigationBar({super.key, required this.currentIndex, required this.destinations});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final duration = media.disableAnimations ? Duration.zero : const Duration(milliseconds: 300);
    final labelSize = destinations.length > 4 ? 10.0 : 11.0;
    final height = 68 + (media.textScaler.scale(labelSize) - labelSize).clamp(0.0, 24.0);
    final Color navigationSurfaceTint = dark
        ? const Color(0xFF292225)
        : const Color(0xFFFFF5F1);
    return GlassSurface(
      radius: 36,
      padding: const EdgeInsets.all(6),
      opacity: .88,
      tintColor: navigationSurfaceTint,
      borderColor: colors.primary.withValues(alpha: dark ? .38 : .27),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / destinations.length;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final index = rtl ? destinations.length - 1 - currentIndex : currentIndex;
          return Stack(children: [
            AnimatedPositioned(
              duration: duration, curve: Curves.easeOutCubic,
              left: index * itemWidth, top: 0, bottom: 0, width: itemWidth,
              child: IgnorePointer(child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(29),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? .20 : .28),
                  ),
                ),
              )),
            ),
            Row(children: [
              for (int i = 0; i < destinations.length; i++)
                Expanded(child: Semantics(
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
                        child: ExcludeSemantics(child: SizedBox.expand(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            AnimatedScale(
                              scale: i == currentIndex ? 1.06 : 1,
                              duration: duration,
                              child: Badge.count(
                                count: destinations[i].badgeCount,
                                isLabelVisible: destinations[i].badgeCount > 0,
                                child: Icon(i == currentIndex ? destinations[i].selectedIcon : destinations[i].icon,
                                  color: i == currentIndex ? colors.onPrimary : colors.onSurface.withValues(alpha: .60), size: 23),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(destinations[i].label, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: labelSize, fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.w500,
                                  color: i == currentIndex ? colors.onPrimary : colors.onSurface.withValues(alpha: .65))),
                            ),
                          ]),
                        )),
                      ),
                    ),
                  ),
                )),
            ]),
          ]);
        }),
      ),
    );
  }
}

class GlassNavigationFrame extends StatelessWidget {
  final Widget child;
  final Widget navigation;
  const GlassNavigationFrame({super.key, required this.child, required this.navigation});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: media.viewInsets.bottom > 0 ? null : SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540), child: navigation),
        ),
      ),
    );
  }
}
