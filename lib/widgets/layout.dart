import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_dimens.dart';

/// Page padding shared by every scrollable screen: a constant side margin on
/// phones, and centred content capped at [AppDimens.maxContentWidth] on wide
/// screens.
EdgeInsets pagePadding(
  BuildContext context, {
  double top = AppDimens.md,
  double bottom = AppDimens.xl,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = math.max(
    AppDimens.pagePadding,
    (width - AppDimens.maxContentWidth) / 2,
  );
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Centres and caps the width of a non-scrolling child (forms, empty states).
class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
          child: child,
        ),
      );
}

/// Vertical gap using the spacing scale.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}
