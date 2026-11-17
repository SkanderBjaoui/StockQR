import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/layout.dart';

/// Shared frame of the login and registration screens.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: pagePadding(context, top: showBack ? AppDimens.sm : AppDimens.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!showBack) ...[
                const Gap(AppDimens.lg),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.apricot,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm + 2),
                    Text(
                      AppConstants.appName,
                      style: AppTheme.serif(size: 26, color: AppColors.forest),
                    ),
                  ],
                ),
                const Gap(AppDimens.xl),
              ],
              Text(title, style: AppTheme.serif(size: 30)),
              const Gap(AppDimens.sm),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.mutedText, height: 1.4),
              ),
              const Gap(AppDimens.lg + 4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline error shown above the submit button of a form.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.md - 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radius),
          border: Border.all(color: AppColors.danger),
        ),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.danger, fontSize: 13.5),
        ),
      );
}
