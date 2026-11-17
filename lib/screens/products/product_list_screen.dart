import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/layout.dart';
import '../../widgets/product_tile.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openForm() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProductFormScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final auth = context.watch<AuthProvider>();
    final products = provider.products;
    final limit = (auth.user?.isAdmin ?? true) ? null : auth.permissions?.maxProducts;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: pagePadding(context, top: AppDimens.lg, bottom: 0),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Produits', style: AppTheme.serif(size: 28)),
                    ),
                    AppButton(
                      label: 'Nouveau produit',
                      style: AppButtonStyle.accent,
                      compact: true,
                      expanded: false,
                      onPressed: _openForm,
                    ),
                  ],
                ),
                const Gap(AppDimens.xs + 2),
                Text(
                  limit == null
                      ? '${provider.products.length} affiché(s)'
                      : 'Quota : ${provider.totalCount} sur $limit produits autorisés',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                  ),
                ),
                const Gap(AppDimens.md),
                AccessBanner(auth.access),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => provider.setQuery(v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom ou code',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer la recherche',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _search.clear();
                              provider.setQuery('');
                            },
                          ),
                  ),
                ),
                if (provider.categories.length > 1) ...[
                  const Gap(AppDimens.sm + 2),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryChip(
                          label: 'Toutes',
                          selected: provider.category == null,
                          onTap: () => provider.setCategory(null),
                        ),
                        for (final c in provider.categories)
                          _CategoryChip(
                            label: c,
                            selected: provider.category == c,
                            onTap: () => provider.setCategory(c),
                          ),
                      ],
                    ),
                  ),
                ],
                const Gap(AppDimens.sm),
                _SortBar(provider: provider),
                const Gap(AppDimens.xs),
              ],
            ),
          ),
          if (provider.isLoading && products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingView(),
            )
          else if (products.isEmpty)
            SliverPadding(
              padding: pagePadding(context, top: AppDimens.sm),
              sliver: SliverToBoxAdapter(
                child: provider.hasActiveFilters
                    ? EmptyState(
                        title: 'Aucun résultat',
                        message:
                            'Aucun produit ne correspond à votre recherche ou '
                            'au filtre sélectionné.',
                        actionLabel: 'Réinitialiser les filtres',
                        onAction: () {
                          _search.clear();
                          provider.clearFilters();
                        },
                      )
                    : EmptyState(
                        title: 'Votre inventaire est vide',
                        message:
                            'Créez un produit : il recevra automatiquement '
                            'son propre QR code.',
                        actionLabel: 'Ajouter un produit',
                        onAction: _openForm,
                      ),
              ),
            )
          else
            SliverPadding(
              padding: pagePadding(context, top: AppDimens.sm),
              sliver: SliverList.separated(
                itemCount: products.length,
                separatorBuilder: (_, _) => const Gap(AppDimens.sm),
                itemBuilder: (context, i) {
                  final product = products[i];
                  return ProductTile(
                    product: product,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProductDetailScreen(productId: product.id!),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: AppDimens.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.parchment : AppColors.charcoal,
          ),
        ),
      );
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.provider});
  final ProductProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Trier par',
          style: TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
        PopupMenuButton<ProductSort>(
          tooltip: 'Choisir le tri',
          initialValue: provider.sort,
          onSelected: provider.setSort,
          itemBuilder: (_) => [
            for (final s in ProductSort.values)
              PopupMenuItem(value: s, child: Text(s.label)),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.sm,
              vertical: AppDimens.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.sort.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.forest,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.forest),
              ],
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: provider.ascending ? 'Ordre croissant' : 'Ordre décroissant',
          visualDensity: VisualDensity.compact,
          onPressed: provider.toggleDirection,
          icon: Icon(
            provider.ascending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 20,
            color: AppColors.forest,
          ),
        ),
      ],
    );
  }
}
