import '../core/constants/app_constants.dart';

/// The text encoded in a product's QR code: `stockqr:v1:<qr_identifier>`.
///
/// Only a stable identifier is encoded, never product data, so a printed
/// label stays valid after the product is edited. The version segment lets a
/// future format coexist with labels already printed.
abstract final class QrPayload {
  static const _prefix =
      '${AppConstants.qrPayloadPrefix}:${AppConstants.qrPayloadVersion}:';

  static String encode(String qrIdentifier) => '$_prefix$qrIdentifier';

  /// Returns the identifier, or null if [raw] is not a StockQR v1 payload.
  static String? decode(String raw) {
    final text = raw.trim();
    if (!text.startsWith(_prefix)) return null;
    final id = text.substring(_prefix.length);
    return id.isEmpty ? null : id;
  }
}
