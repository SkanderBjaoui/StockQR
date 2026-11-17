import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_dimens.dart';
import '../core/errors/app_exception.dart';
import '../data/models/product.dart';
import '../services/permission_service.dart';
import 'app_button.dart';

/// Small uppercase-free section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.sm + 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Bordered surface used to group related content.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.md),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

/// Empty state: a short title, one explanatory line and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.xl,
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedText),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppDimens.lg),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                expanded: false,
              ),
            ],
          ],
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Stock status label: moss when healthy, apricot when low, solid apricot
/// when out of stock. Text always carries the meaning, not colour alone.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color? border) = switch (status) {
      StockStatus.inStock => (AppColors.mossTint, AppColors.forest, null),
      StockStatus.low => (
          AppColors.surface,
          AppColors.charcoal,
          AppColors.apricot,
        ),
      StockStatus.outOfStock => (
          AppColors.apricot,
          AppColors.charcoal,
          null,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radius - 2),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Label on the left, value on the right; used on detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              flex: 6,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Explains a restricted account (expired subscription) at the top of a page.
class AccessBanner extends StatelessWidget {
  const AccessBanner(this.status, {super.key});
  final AccessStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.message == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimens.md),
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radius),
        border: const Border(
          left: BorderSide(color: AppColors.apricot, width: 4),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Text(status.message!, style: const TextStyle(fontSize: 13.5)),
    );
  }
}

/// Snackbar helpers so feedback looks the same everywhere.
abstract final class AppFeedback {
  static void success(BuildContext context, String message) =>
      _show(context, message);

  static void error(BuildContext context, Object error) {
    final text = error is AppException
        ? error.message
        : "Une erreur inattendue s'est produite.";
    _show(context, text, isError: true);
  }

  static void _show(BuildContext context, String message,
      {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: isError ? 5 : 3),
        // A thin apricot edge distinguishes errors without a new colour.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          side: isError
              ? const BorderSide(color: AppColors.apricot, width: 1.5)
              : BorderSide.none,
        ),
      ),
    );
  }
}

/// Confirmation dialog. Returns true only when the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppDimens.md,
        0,
        AppDimens.md,
        AppDimens.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, AppDimens.compactControlHeight),
            backgroundColor: destructive ? AppColors.danger : AppColors.forest,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
