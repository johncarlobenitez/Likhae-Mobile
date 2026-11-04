import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'motion_effects.dart';

enum LoadingLayout { list, products, productDetails }

/// Placeholder layout is static; lightweight sweeps repaint independently.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.layout = LoadingLayout.list});

  final LoadingLayout layout;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppLoadingLine(),
            const SizedBox(height: 24),
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.55,
                    child: _SkeletonBlock(height: 22),
                  ),
                  const SizedBox(height: 10),
                  const FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.8,
                    child: _SkeletonBlock(height: 12),
                  ),
                  const SizedBox(height: 28),
                  if (layout == LoadingLayout.products) ...[
                    const ProductGridSkeleton(),
                    const SizedBox(height: 24),
                    const ProductGridSkeleton(),
                  ] else if (layout == LoadingLayout.productDetails) ...[
                    const AspectRatio(
                      aspectRatio: 1.35,
                      child: _SkeletonBlock(),
                    ),
                    const SizedBox(height: 24),
                    const _SkeletonBlock(height: 20),
                    const SizedBox(height: 12),
                    const FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.4,
                      child: _SkeletonBlock(height: 18),
                    ),
                  ] else
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          children: [
                            const SizedBox.square(
                              dimension: 62,
                              child: _SkeletonBlock(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _SkeletonBlock(height: 15),
                                  const SizedBox(height: 10),
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: i.isEven ? 0.65 : 0.45,
                                    child: const _SkeletonBlock(height: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading products',
    child: AppSkeletonSweep(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 170).floor().clamp(1, 4);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(aspectRatio: 1, child: _SkeletonBlock()),
                        SizedBox(height: 14),
                        _SkeletonBlock(height: 14),
                        SizedBox(height: 10),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.55,
                          child: _SkeletonBlock(height: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
