import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/layout.dart';

/// Create (when [product] is null) or edit a product.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _sku = TextEditingController(text: widget.product?.sku);
  late final _barcode = TextEditingController(text: widget.product?.barcode);
  late final _description =
      TextEditingController(text: widget.product?.description);
  late final _category = TextEditingController(
    text: widget.product?.category ?? AppConstants.defaultCategories.first,
  );
  late final _purchase = TextEditingController(
    text: widget.product == null
        ? ''
        : Fmt.decimalInput(widget.product!.purchasePrice),
  );
  late final _selling = TextEditingController(
    text: widget.product == null
        ? ''
        : Fmt.decimalInput(widget.product!.sellingPrice),
  );
  late final _quantity = TextEditingController(
    text: widget.product?.quantity.toString() ?? '0',
  );
  late final _threshold = TextEditingController(
    text: widget.product?.minStockThreshold.toString() ?? '5',
  );

  bool _busy = false;
  String? _skuError; // duplicate SKU reported by the service
  String? _formError;

  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    for (final c in [
      _name, _sku, _barcode, _description, _category,
      _purchase, _selling, _quantity, _threshold, //
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _skuError = null;
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final input = ProductInput(
      name: _name.text,
      sku: _sku.text,
      barcode: _barcode.text,
      description: _description.text,
      category: _category.text,
      purchasePrice: Fmt.parseDecimal(_purchase.text)!,
      sellingPrice: Fmt.parseDecimal(_selling.text)!,
      quantity: int.parse(_quantity.text.trim()),
      minStockThreshold: int.parse(_threshold.text.trim()),
    );

    setState(() => _busy = true);
    final provider = context.read<ProductProvider>();
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEdit) {
        await provider.update(widget.product!.id!, input);
      } else {
        await provider.create(input);
      }
      messenger.hideCurrentSnackBar();
      navigator.pop(true);
    } on DuplicateException catch (e) {
      if (!mounted) return;
      setState(() => _skuError = e.message);
      _formKey.currentState!.validate();
    } on PermissionDeniedException catch (e) {
      // The admin may have changed this account since sign-in.
      auth.refresh();
      if (mounted) setState(() => _formError = e.message);
    } on AppException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _formError = "L'enregistrement a échoué. Réessayez.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = context.watch<ProductProvider>().categories;
    final suggestions = {
      ...existing,
      ...AppConstants.defaultCategories,
    }.toList();
    final decimalFormatter =
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier le produit' : 'Nouveau produit')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: pagePadding(context),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Identification'),
                LabeledField(
                  label: 'Nom du produit',
                  controller: _name,
                  validator: (v) =>
                      Validators.required(v, label: 'Le nom du produit'),
                ),
                const Gap(AppDimens.md),
                LabeledField(
                  label: 'Code produit (SKU)',
                  controller: _sku,
                  helper: 'Unique dans votre inventaire.',
                  onChanged: (_) {
                    if (_skuError != null) setState(() => _skuError = null);
                  },
                  validator: (v) =>
                      Validators.required(v, label: 'Le code produit') ??
                      _skuError,
                ),
                const Gap(AppDimens.md),
                LabeledField(
                  label: 'Code-barres',
                  optional: true,
                  controller: _barcode,
                  keyboardType: TextInputType.number,
                ),
                const Gap(AppDimens.md),
                LabeledField(
                  label: 'Catégorie',
                  controller: _category,
                  validator: (v) =>
                      Validators.required(v, label: 'La catégorie'),
                ),
                const Gap(AppDimens.sm),
                Wrap(
                  spacing: AppDimens.sm,
                  runSpacing: AppDimens.sm,
                  children: [
                    for (final c in suggestions)
                      ActionChip(
                        label: Text(c),
                        onPressed: () => setState(() => _category.text = c),
                      ),
                  ],
                ),
                const Gap(AppDimens.md),
                LabeledField(
                  label: 'Description',
                  optional: true,
                  controller: _description,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                ),
                const Gap(AppDimens.xl),
                const SectionHeader('Tarification'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: "Prix d'achat",
                        controller: _purchase,
                        suffixText: AppConstants.currencySymbol,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [decimalFormatter],
                        validator: (v) =>
                            Validators.price(v, label: "Le prix d'achat"),
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: LabeledField(
                        label: 'Prix de vente',
                        controller: _selling,
                        suffixText: AppConstants.currencySymbol,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [decimalFormatter],
                        validator: (v) =>
                            Validators.price(v, label: 'Le prix de vente'),
                      ),
                    ),
                  ],
                ),
                const Gap(AppDimens.xl),
                const SectionHeader('Stock'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'Quantité disponible',
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: Validators.quantity,
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: LabeledField(
                        label: 'Seuil minimum',
                        controller: _threshold,
                        helper: 'Stock bas en dessous de ce seuil.',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) =>
                            Validators.quantity(v, label: 'Le seuil'),
                      ),
                    ),
                  ],
                ),
                if (_formError != null) ...[
                  const Gap(AppDimens.lg),
                  Panel(
                    child: Text(
                      _formError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
                const Gap(AppDimens.xl),
                AppButton(
                  label: _isEdit ? 'Enregistrer les modifications' : 'Créer le produit',
                  busy: _busy,
                  onPressed: _save,
                ),
                const Gap(AppDimens.sm),
                AppButton(
                  label: 'Annuler',
                  style: AppButtonStyle.outlined,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
