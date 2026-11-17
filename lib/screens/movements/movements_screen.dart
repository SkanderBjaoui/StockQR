import 'package:flutter/material.dart';

import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/layout.dart';

/// Stock movements (entries, exits, sales). The tables are already part of the
/// database schema; recording and scanning arrive in Part 2.
class MovementsScreen extends StatelessWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: pagePadding(context, top: AppDimens.lg),
        children: [
          Text('Mouvements', style: AppTheme.serif(size: 28)),
          const Gap(AppDimens.lg),
          const EmptyState(
            title: 'Aucun mouvement enregistré',
            message:
                'Les entrées, sorties et ventes de stock seront disponibles '
                'dans la prochaine version, avec le scan des QR codes.',
          ),
        ],
      ),
    );
  }
}
