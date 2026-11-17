import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/layout.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await confirmAction(
      context,
      title: 'Se déconnecter ?',
      message: 'Vos données restent enregistrées sur cet appareil.',
      confirmLabel: 'Se déconnecter',
    );
    if (ok) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink(); // signing out
    final perms = auth.permissions;
    final access = auth.access;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: pagePadding(context, top: AppDimens.lg),
        children: [
          Text('Profil', style: AppTheme.serif(size: 28)),
          const Gap(AppDimens.lg),
          AccessBanner(access),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: AppTheme.serif(size: 22)),
                const Gap(AppDimens.xs),
                Text(
                  user.role.label,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                  ),
                ),
                const Gap(AppDimens.md),
                const Divider(),
                const Gap(AppDimens.xs),
                InfoRow("Nom d'utilisateur", user.username),
                InfoRow('E-mail', user.email),
                InfoRow('Membre depuis', Fmt.date(user.createdAt)),
              ],
            ),
          ),
          if (!user.isAdmin && perms != null) ...[
            const Gap(AppDimens.lg),
            const SectionHeader('Abonnement et permissions'),
            Panel(
              child: Column(
                children: [
                  InfoRow(
                    'Statut',
                    perms.isExpiredAt(DateTime.now()) ? 'Expiré' : 'Actif',
                    emphasize: true,
                  ),
                  InfoRow('Début', Fmt.date(perms.subscriptionStart)),
                  InfoRow(
                    'Fin',
                    perms.subscriptionEnd == null
                        ? 'Sans limite'
                        : Fmt.date(perms.subscriptionEnd!),
                  ),
                  InfoRow('Produits autorisés', Fmt.integer(perms.maxProducts)),
                  InfoRow('Scan QR / code-barres',
                      perms.canScan ? 'Autorisé' : 'Non autorisé'),
                ],
              ),
            ),
          ],
          const Gap(AppDimens.lg),
          const SectionHeader('Sécurité'),
          AppButton(
            label: 'Changer le mot de passe',
            style: AppButtonStyle.outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChangePasswordScreen(),
              ),
            ),
          ),
          const Gap(AppDimens.sm),
          AppButton(
            label: 'Se déconnecter',
            style: AppButtonStyle.destructive,
            onPressed: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
