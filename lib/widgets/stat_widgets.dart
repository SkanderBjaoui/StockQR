import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_dimens.dart';
import '../core/theme/app_theme.dart';

/// The single most important figure of a screen: forest background, large
/// serif number.
class HeroStat extends StatelessWidget {
  const HeroStat({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.lg - 4),
        decoration: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.moss,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTheme.serif(
                  size: 38,
                  color: AppColors.parchment,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              caption,
              style: const TextStyle(
                color: AppColors.parchment,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
}

/// A secondary figure: small muted label, readable number, optional caption.
/// [highlight] draws the number in deep apricot (used for missing products).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.highlight = false,
    this.valueSize = 22,
  });

  final String label;
  final String value;
  final String? caption;
  final bool highlight;
  final double valueSize;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTheme.serif(
                  size: valueSize,
                  color: highlight ? AppColors.danger : AppColors.charcoal,
                ),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: AppDimens.xs + 2),
              Text(
                caption!,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      );
}

/// Lays tiles out in equal-width rows. Collapses to a single column when the
/// available width is too small for [minTileWidth], so numbers never clip.
class StatGrid extends StatelessWidget {
  const StatGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.minTileWidth = 140,
  });

  final List<Widget> children;
  final int columns;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          var cols = columns;
          while (cols > 1 &&
              (constraints.maxWidth - AppDimens.sm * (cols - 1)) / cols <
                  minTileWidth) {
            cols--;
          }
          final rows = <Widget>[];
          for (var i = 0; i < children.length; i += cols) {
            final slice = children.skip(i).take(cols).toList();
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < cols; j++) ...[
                      if (j > 0) const SizedBox(width: AppDimens.sm + 2),
                      Expanded(
                        child: j < slice.length ? slice[j] : const SizedBox(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: AppDimens.sm + 2),
                rows[i],
              ],
            ],
          );
        },
      );
}
