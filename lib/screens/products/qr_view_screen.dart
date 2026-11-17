import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../services/qr_label_service.dart';
import '../../services/qr_payload.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/layout.dart';

/// Full-screen QR label for one product, shareable as a printable PNG.
class QrViewScreen extends StatefulWidget {
  const QrViewScreen({super.key, required this.product});

  final Product product;

  @override
  State<QrViewScreen> createState() => _QrViewScreenState();
}

class _QrViewScreenState extends State<QrViewScreen> {
  bool _sharing = false;

  Future<void> _share() async {
    final product = widget.product;
    setState(() => _sharing = true);
    try {
      final file = await const QrLabelService().renderToFile(
        qrIdentifier: product.qrIdentifier,
        name: product.name,
        sku: product.sku,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'QR code · ${product.name}',
        ),
      );
    } catch (_) {
      if (mounted) {
        AppFeedback.error(
          context,
          const _ShareFailure(),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: QrPayload.encode(widget.product.qrIdentifier)),
    );
    if (mounted) {
      AppFeedback.success(context, 'Contenu du QR code copié.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final payload = QrPayload.encode(product.qrIdentifier);

    return Scaffold(
      appBar: AppBar(title: const Text('QR code')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: pagePadding(context),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimens.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => QrImageView(
                        data: payload,
                        size: constraints.maxWidth.clamp(180, 360).toDouble(),
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.charcoal,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.charcoal,
                        ),
                        semanticsLabel: 'QR code du produit ${product.name}',
                      ),
                    ),
                    const Gap(AppDimens.lg),
                    Text(
                      product.name,
                      textAlign: TextAlign.center,
                      style: AppTheme.serif(size: 22),
                    ),
                    const Gap(AppDimens.xs + 2),
                    Text(
                      product.sku,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppDimens.md),
              Text(
                payload,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11.5,
                ),
              ),
              const Gap(AppDimens.sm),
              const Text(
                'Ce code contient uniquement un identifiant stable : il reste '
                'valable même si le produit est modifié.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText, fontSize: 12.5),
              ),
              const Gap(AppDimens.lg),
              AppButton(
                label: "Partager l'étiquette (PNG)",
                busy: _sharing,
                onPressed: _share,
              ),
              const Gap(AppDimens.sm),
              AppButton(
                label: 'Copier le contenu',
                style: AppButtonStyle.outlined,
                onPressed: _copy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareFailure extends AppException {
  const _ShareFailure()
      : super("Le partage a échoué sur cet appareil. Réessayez.");
}
