import 'package:flutter/material.dart';

/// Common timing and accessibility policy for small, interruptible effects.
abstract final class AppMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const emphasis = Duration(milliseconds: 520);
  static const entrance = Duration(milliseconds: 620);
  static const settle = Curves.easeOutCubic;
}

bool appReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

Duration appMotionDuration(BuildContext context, {int milliseconds = 200}) =>
    appReduceMotion(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);
