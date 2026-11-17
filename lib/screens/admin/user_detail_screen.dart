import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../providers/admin_provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/layout.dart';
import '../../widgets/stat_widgets.dart';

/// One account: its inventory figures, status and configurable permissions.
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maxProducts = TextEditingController();

  UserDetail? _detail;
  Object? _loadError;
  bool _canScan = true;
  DateTime? _subscriptionEnd;
  bool _saving = false;
  bool _togglingActive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _maxProducts.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await context.read<AdminProvider>().detail(widget.userId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _canScan = detail.permissions.canScan;
        _subscriptionEnd = detail.permissions.subscriptionEnd;
        _maxProducts.text = detail.permissions.maxProducts.toString();
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _subscriptionEnd?.toLocal() ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
      helpText: "Fin de l'abonnement",
    );
    if (picked != null) {
      // The subscription lasts through the whole chosen day.
      setState(() => _subscriptionEnd =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
    }
  }

  Future<void> _savePermissions() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final admin = context.read<AdminProvider>();
    try {
      await admin.updatePermissions(
        widget.userId,
        canScan: _canScan,
        maxProducts: int.parse(_maxProducts.text.trim()),
        subscriptionEnd: _subscriptionEnd,
      );
      await _load();
      if (mounted) AppFeedback.success(context, 'Permissions enregistrées.');
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive(bool active) async {
    final user = _detail!.user;
    if (!active) {
      final ok = await confirmAction(
        context,
        title: 'Désactiver ce compte ?',
        message: '${user.fullName} ne pourra plus se connecter. Ses données '
            'sont conservées et le compte pourra être réactivé.',
        confirmLabel: 'Désactiver',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _togglingActive = true);
    final admin = context.read<AdminProvider>();
    try {
      await admin.setActive(user.id, active);
      await _load();
      if (mounted) {
        AppFeedback.success(
          context,
          active ? 'Compte réactivé.' : 'Compte désactivé.',
        );
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _togglingActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compte utilisateur')),
      body: SafeArea(
        child: _loadError != null
            ? Padding(
                padding: pagePadding(context),
                child: EmptyState(
                  title: 'Compte indisponible',
                  message: _loadError is Exception
                      ? _loadError.toString()
                      : 'Impossible de charger ce compte.',
                ),
              )
            : _detail == null
                ? const LoadingView()
                : _buildContent(context, _detail!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserDetail d) {
    final user = d.user;
    final stats = d.stats;
    final expired = d.permissions.isExpiredAt(DateTime.now());

    return ListView(
      padding: pagePadding(context),
      children: [
        Text(user.fullName, style: AppTheme.serif(size: 28)),
        const Gap(AppDimens.xs + 2),
        Text(
          '@${user.username}  ·  ${user.email}',
          style: const TextStyle(color: AppColors.mutedText),
        ),
        const Gap(AppDimens.lg),

        // --- Account status --------------------------------------------------
        const SectionHeader('Compte'),
        Panel(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Compte actif',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.isActive
                              ? "L'utilisateur peut se connecter."
                              : 'Connexion bloquée. Données conservées.',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: user.isActive,
                    onChanged: _togglingActive ? null : _toggleActive,
                  ),
                ],
              ),
              const Divider(height: AppDimens.lg),
              InfoRow('Inscrit le', Fmt.date(user.createdAt)),
              InfoRow(
                'Abonnement',
                expired ? 'Expiré' : 'En cours',
                emphasize: true,
              ),
            ],
          ),
        ),
        const Gap(AppDimens.lg),

        // --- Inventory figures -----------------------------------------------
        const SectionHeader('Inventaire'),
        StatGrid(
          minTileWidth: 150,
          children: [
            StatTile(
              label: 'Revenus du mois',
              value: Fmt.currency(stats.monthlyIncome),
            ),
            StatTile(
              label: 'Valeur du stock',
              value: Fmt.currency(stats.stockValue),
            ),
            StatTile(
              label: 'Revenu potentiel',
              value: Fmt.currency(stats.potentialRevenue),
            ),
            StatTile(
              label: 'Produits',
              value: Fmt.integer(stats.productCount),
              caption:
                  '${stats.inStockCount} en stock · ${stats.outOfStockCount} manquant(s)',
            ),
          ],
        ),
        const Gap(AppDimens.lg),

        // --- Permissions -------------------------------------------------------
        const SectionHeader('Permissions'),
        Panel(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Scan QR / code-barres',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch(
                      value: _canScan,
                      onChanged: (v) => setState(() => _canScan = v),
                    ),
                  ],
                ),
                const Gap(AppDimens.md),
                LabeledField(
                  label: 'Nombre maximum de produits',
                  controller: _maxProducts,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) =>
                      Validators.quantity(v, label: 'Le maximum'),
                ),
                const Gap(AppDimens.md),
                const Text(
                  "Fin de l'abonnement",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Gap(AppDimens.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _subscriptionEnd == null
                            ? 'Sans limite'
                            : Fmt.date(_subscriptionEnd!),
                        style: TextStyle(
                          fontSize: 15,
                          color: _subscriptionEnd != null &&
                                  _subscriptionEnd!.isBefore(DateTime.now())
                              ? AppColors.danger
                              : AppColors.charcoal,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickEndDate,
                      child: const Text('Choisir une date'),
                    ),
                    if (_subscriptionEnd != null)
                      TextButton(
                        onPressed: () => setState(() => _subscriptionEnd = null),
                        child: const Text('Sans limite'),
                      ),
                  ],
                ),
                Wrap(
                  spacing: AppDimens.sm,
                  children: [
                    for (final days in const [30, 90, 365])
                      ActionChip(
                        label: Text('+$days j'),
                        onPressed: () {
                          // Extend from today, or from the current end if it
                          // is still in the future.
                          final base = (_subscriptionEnd != null &&
                                  _subscriptionEnd!.isAfter(DateTime.now()))
                              ? _subscriptionEnd!
                              : DateTime.now();
                          setState(() =>
                              _subscriptionEnd = base.add(Duration(days: days)));
                        },
                      ),
                  ],
                ),
                const Gap(AppDimens.lg),
                AppButton(
                  label: 'Enregistrer les permissions',
                  busy: _saving,
                  onPressed: _savePermissions,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
