import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_user.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/layout.dart';
import '../../widgets/stat_widgets.dart';
import 'user_detail_screen.dart';

/// Administration home: global figures and the list of accounts.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final stats = admin.stats;

    if (admin.isLoading && stats == null) return const LoadingView();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: pagePadding(context, top: AppDimens.lg),
        children: [
          Text('Administration', style: AppTheme.serif(size: 28)),
          const Gap(AppDimens.xs + 2),
          const Text(
            'Chiffres cumulés de tous les comptes.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
          const Gap(AppDimens.lg),
          if (stats != null) ...[
            HeroStat(
              label: 'REVENUS DU MOIS · TOUS COMPTES',
              value: Fmt.currency(stats.monthlyIncome),
              caption: stats.monthlyIncome == 0
                  ? 'Aucune vente enregistrée ce mois-ci.'
                  : 'Ventes réellement encaissées ce mois-ci.',
            ),
            const Gap(AppDimens.sm + 2),
            StatGrid(
              minTileWidth: 150,
              children: [
                StatTile(
                  label: 'Valeur du stock',
                  value: Fmt.currency(stats.stockValue),
                  caption: "Quantités × prix d'achat.",
                ),
                StatTile(
                  label: 'Quantité en stock',
                  value: Fmt.integer(stats.totalQuantity),
                  caption: 'unités, tous comptes',
                ),
              ],
            ),
            const Gap(AppDimens.sm + 2),
            StatGrid(
              columns: 3,
              minTileWidth: 96,
              children: [
                StatTile(
                  label: 'Utilisateurs',
                  value: Fmt.integer(stats.userCount),
                  caption: 'inscrits',
                ),
                StatTile(
                  label: 'Produits',
                  value: Fmt.integer(stats.productCount),
                  caption: 'au total',
                ),
                StatTile(
                  label: 'Comptes actifs',
                  value: '${stats.activeUsers}',
                  caption: '${stats.inactiveUsers} inactif(s)',
                ),
              ],
            ),
          ],
          const Gap(AppDimens.xl),
          const SectionHeader('Comptes utilisateurs'),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: admin.search,
            decoration: InputDecoration(
              hintText: 'Rechercher un nom, un identifiant ou un e-mail',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        admin.search('');
                      },
                    ),
            ),
          ),
          const Gap(AppDimens.md),
          if (admin.users.isEmpty)
            EmptyState(
              title: admin.query.isEmpty
                  ? 'Aucun utilisateur inscrit'
                  : 'Aucun résultat',
              message: admin.query.isEmpty
                  ? "Les comptes créés depuis l'écran d'inscription "
                      'apparaîtront ici.'
                  : 'Aucun compte ne correspond à cette recherche.',
            )
          else
            for (final user in admin.users) ...[
              _UserTile(user: user),
              const Gap(AppDimens.sm),
            ],
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UserDetailScreen(userId: user.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@${user.username}  ·  ${user.email}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.md),
              _ActiveChip(active: user.isActive),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppColors.mossTint : AppColors.apricot,
          borderRadius: BorderRadius.circular(AppDimens.radius - 2),
        ),
        child: Text(
          active ? 'Actif' : 'Désactivé',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.forest : AppColors.charcoal,
          ),
        ),
      );
}
