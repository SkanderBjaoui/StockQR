import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants/app_colors.dart';
import 'qr_payload.dart';

/// Renders a printable QR label (QR, quiet zone, name and SKU) as a PNG.
///
/// The background is pure white on purpose: scanners need maximum contrast,
/// and the label is meant to be printed.
class QrLabelService {
  const QrLabelService();

  static const _qrSize = 800.0;
  static const _margin = 100.0;

  Future<List<int>> renderPng({
    required String qrIdentifier,
    required String name,
    required String sku,
  }) async {
    const width = _qrSize + _margin * 2;
    const height = width + 170;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final painter = QrPainter(
      data: QrPayload.encode(qrIdentifier),
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.charcoal,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.charcoal,
      ),
    );
    canvas.save();
    canvas.translate(_margin, _margin);
    painter.paint(canvas, const Size(_qrSize, _qrSize));
    canvas.restore();

    _drawCentered(canvas, name, width, _margin + _qrSize + 30,
        size: 52, weight: FontWeight.w700, color: AppColors.charcoal);
    _drawCentered(canvas, sku, width, _margin + _qrSize + 100,
        size: 40, weight: FontWeight.w500, color: AppColors.mutedText);

    final image = await recorder
        .endRecording()
        .toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Writes the label to a temporary file, ready to be shared or printed.
  Future<File> renderToFile({
    required String qrIdentifier,
    required String name,
    required String sku,
  }) async {
    final bytes =
        await renderPng(qrIdentifier: qrIdentifier, name: name, sku: sku);
    final dir = await getTemporaryDirectory();
    final safeSku = sku.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}qr_$safeSku.png');
    return file.writeAsBytes(bytes, flush: true);
  }

  void _drawCentered(
    Canvas canvas,
    String text,
    double width,
    double top, {
    required double size,
    required FontWeight weight,
    required Color color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, fontWeight: weight, color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width - _margin);
    tp.paint(canvas, Offset((width - tp.width) / 2, top));
  }
}
