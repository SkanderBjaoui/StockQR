import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/qr_payload.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/layout.dart';
import 'product_form_screen.dart';
import 'qr_view_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final product =
        await context.read<ProductProvider>().byId(widget.productId);
    if (!mounted) return;
    setState(() {
      _product = product;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: _product),
      ),
    );
    if (saved == true) {
      await _load();
      if (mounted) AppFeedback.success(context, 'Produit mis à jour.');
    }
  }

  Future<void> _delete() async {
    final product = _product!;
    final confirmed = await confirmAction(
      context,
      title: 'Supprimer ce produit ?',
      message:
          '« ${product.name} » et son QR code seront définitivement supprimés. '
          'Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ProductProvider>().delete(product.id!);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('« ${product.name} » supprimé.')));
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        AppFeedback.error(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AuthProvider>().access;

    return Scaffold(
      appBar: AppBar(title: const Text('Détail du produit')),
      body: SafeArea(
        child: _loading
            ? const LoadingView()
            : _product == null
                ? Padding(
                    padding: pagePadding(context),
                    child: const EmptyState(
                      title: 'Produit introuvable',
                      message: "Ce produit n'existe plus ou a été supprimé.",
                    ),
                  )
                : _buildContent(context, _product!, access.canWrite),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Product p, bool canWrite) {
    final access = context.watch<AuthProvider>().access;
    return ListView(
      padding: pagePadding(context),
      children: [
        AccessBanner(access),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(p.name, style: AppTheme.serif(size: 28))),
            const SizedBox(width: AppDimens.md),
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.sm),
              child: StatusChip(p.status),
            ),
          ],
        ),
        const Gap(AppDimens.xs + 2),
        Text(
          '${p.sku}  ·  ${p.category}',
          style: const TextStyle(color: AppColors.mutedText),
        ),
        const Gap(AppDimens.lg),

        // --- Stock ---------------------------------------------------------
        const SectionHeader('Stock'),
        Panel(
          child: Column(
            children: [
              InfoRow('Quantité disponible', Fmt.integer(p.quantity),
                  emphasize: true),
              InfoRow('Seuil minimum', Fmt.integer(p.minStockThreshold)),
            ],
          ),
        ),
        const Gap(AppDimens.lg),

        // --- Pricing -------------------------------------------------------
        const SectionHeader('Tarification'),
        Panel(
          child: Column(
            children: [
              InfoRow("Prix d'achat", Fmt.currency(p.purchasePrice)),
              InfoRow('Prix de vente', Fmt.currency(p.sellingPrice)),
              InfoRow('Marge unitaire', Fmt.currency(p.unitMargin)),
              const Divider(height: AppDimens.md),
              InfoRow('Valeur du stock', Fmt.currency(p.stockValue)),
              InfoRow('Revenu potentiel', Fmt.currency(p.potentialRevenue)),
            ],
          ),
        ),
        const Gap(AppDimens.lg),

        // --- Information ---------------------------------------------------
        const SectionHeader('Informations'),
        Panel(
          child: Column(
            children: [
              InfoRow('Catégorie', p.category),
              InfoRow('Code-barres', p.barcode ?? '—'),
              InfoRow('Description', p.description ?? '—'),
              InfoRow('Créé le', Fmt.dateTime(p.createdAt)),
              InfoRow('Modifié le', Fmt.dateTime(p.updatedAt)),
            ],
          ),
        ),
        const Gap(AppDimens.lg),

        // --- QR code -------------------------------------------------------
        const SectionHeader('QR code'),
        Panel(
          child: Row(
            children: [
              InkWell(
                onTap: () => _openQr(p),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(AppDimens.sm),
                  child: QrImageView(
                    data: QrPayload.encode(p.qrIdentifier),
                    size: 112,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.charcoal,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identifiant unique du produit',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppDimens.xs),
                    Text(
                      p.qrIdentifier.substring(0, 8).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppDimens.sm + 2),
                    AppButton(
                      label: 'Afficher / partager',
                      style: AppButtonStyle.outlined,
                      compact: true,
                      onPressed: () => _openQr(p),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(AppDimens.xl),

        // --- Actions -------------------------------------------------------
        AppButton(
          label: 'Modifier',
          onPressed: canWrite && !_deleting ? _edit : null,
        ),
        const Gap(AppDimens.sm),
        AppButton(
          label: 'Supprimer',
          style: AppButtonStyle.destructive,
          busy: _deleting,
          onPressed: canWrite ? _delete : null,
        ),
      ],
    );
  }

  void _openQr(Product p) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => QrViewScreen(product: p)),
      );
}
