import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/layout.dart';
import '../../widgets/product_tile.dart';
import '../../widgets/stat_widgets.dart';
import '../products/product_detail_screen.dart';
import '../products/product_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSeeAllProducts});

  /// Switches the shell to the Products tab.
  final VoidCallback onSeeAllProducts;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink(); // signing out
    final stats = dash.stats;
    final now = DateTime.now();

    if (dash.isLoading) return const LoadingView();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: pagePadding(context, top: AppDimens.lg),
        children: [
          // --- Greeting + primary shortcut -----------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fmt.longDay(now),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                    const SizedBox(height: AppDimens.xs),
                    Text(
                      'Bonjour, ${user.fullName}',
                      style: AppTheme.serif(size: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.md),
              AppButton(
                label: 'Nouveau produit',
                style: AppButtonStyle.accent,
                compact: true,
                expanded: false,
                onPressed: () => _openForm(context),
              ),
            ],
          ),
          const Gap(AppDimens.lg),
          AccessBanner(auth.access),

          // --- Revenue: the headline figure ----------------------------------
          HeroStat(
            label: 'REVENUS DU MOIS · ${Fmt.month(now).toUpperCase()}',
            value: Fmt.currency(stats.monthlyIncome),
            caption: stats.monthlyIncome == 0
                ? 'Aucune vente enregistrée ce mois-ci.'
                : 'Ventes réellement encaissées ce mois-ci.',
          ),
          const Gap(AppDimens.sm + 2),

          // --- Stock value vs. potential revenue -----------------------------
          StatGrid(
            minTileWidth: 150,
            children: [
              StatTile(
                label: 'Valeur du stock',
                value: Fmt.currency(stats.stockValue),
                caption: "Quantités × prix d'achat : ce que le stock a coûté.",
              ),
              StatTile(
                label: 'Revenu potentiel',
                value: Fmt.currency(stats.potentialRevenue),
                caption: 'Quantités × prix de vente, si tout était vendu.',
              ),
            ],
          ),
          const Gap(AppDimens.sm + 2),

          // --- Counters -------------------------------------------------------
          StatGrid(
            columns: 3,
            minTileWidth: 96,
            children: [
              StatTile(
                label: 'Quantité totale',
                value: Fmt.integer(stats.totalQuantity),
                caption: 'unités',
              ),
              StatTile(
                label: 'En stock',
                value: Fmt.integer(stats.inStockCount),
                caption: 'produits',
              ),
              StatTile(
                label: 'Manquants',
                value: Fmt.integer(stats.outOfStockCount),
                caption: 'produits',
                highlight: stats.outOfStockCount > 0,
              ),
            ],
          ),
          const Gap(AppDimens.xl),

          // --- Recent products ------------------------------------------------
          SectionHeader(
            'Produits récents',
            trailing: dash.recent.isEmpty
                ? null
                : TextButton(
                    onPressed: onSeeAllProducts,
                    child: const Text('Voir tout'),
                  ),
          ),
          if (dash.recent.isEmpty)
            EmptyState(
              title: 'Aucun produit pour le moment',
              message:
                  'Ajoutez votre premier produit pour voir apparaître vos '
                  'statistiques et générer son QR code.',
              actionLabel: 'Ajouter un produit',
              onAction: () => _openForm(context),
            )
          else
            for (final product in dash.recent) ...[
              ProductTile(
                product: product,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProductDetailScreen(productId: product.id!),
                  ),
                ),
              ),
              const Gap(AppDimens.sm),
            ],
        ],
      ),
    );
  }

  void _openForm(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProductFormScreen()),
      );
}
