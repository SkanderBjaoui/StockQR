import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_dimens.dart';

enum AppButtonStyle { primary, accent, outlined, destructive }

/// The one button used across the app: same height, radius and type for every
/// variant, with a built-in busy state.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.busy = false,
    this.expanded = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;

  /// Shows a spinner and ignores taps while an operation is running.
  final bool busy;
  final bool expanded;

  /// Smaller height for inline actions (e.g. list headers).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height =
        compact ? AppDimens.compactControlHeight : AppDimens.controlHeight;
    final size = Size(expanded ? double.infinity : 0, height);
    final effective = busy ? null : onPressed;

    final Color spinnerColor = switch (style) {
      AppButtonStyle.primary => AppColors.parchment,
      AppButtonStyle.accent => AppColors.charcoal,
      AppButtonStyle.outlined => AppColors.forest,
      AppButtonStyle.destructive => AppColors.danger,
    };
    final child = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          )
        : Text(label);

    switch (style) {
      case AppButtonStyle.primary:
        return FilledButton(
          onPressed: effective,
          style: FilledButton.styleFrom(minimumSize: size),
          child: child,
        );
      case AppButtonStyle.accent:
        return FilledButton(
          onPressed: effective,
          style: FilledButton.styleFrom(
            minimumSize: size,
            backgroundColor: AppColors.apricot,
            foregroundColor: AppColors.charcoal,
          ),
          child: child,
        );
      case AppButtonStyle.outlined:
        return OutlinedButton(
          onPressed: effective,
          style: OutlinedButton.styleFrom(minimumSize: size),
          child: child,
        );
      case AppButtonStyle.destructive:
        return OutlinedButton(
          onPressed: effective,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          child: child,
        );
    }
  }
}
