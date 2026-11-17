import 'package:flutter/painting.dart';

/// The five brand colours plus a few neutral tints derived from them.
///
/// Nothing outside this palette is used anywhere in the UI.
abstract final class AppColors {
  // Brand palette.
  static const forest = Color(0xFF203A34);
  static const apricot = Color(0xFFD68C65);
  static const parchment = Color(0xFFF2EBDD);
  static const moss = Color(0xFFA7B59A);
  static const charcoal = Color(0xFF252B28);

  // Derived tints (lighter / darker steps of the palette above).
  /// Parchment lifted towards white, used for cards sitting on parchment.
  static const surface = Color(0xFFF9F5EB);

  /// Parchment pushed towards charcoal, used for hairline borders.
  static const border = Color(0xFFD9CFBA);

  /// Charcoal softened for secondary text (contrast >= 4.5 on parchment).
  static const mutedText = Color(0xFF5B645F);

  /// Apricot deepened so it stays legible as text and for destructive actions.
  static const danger = Color(0xFFA24F2C);

  /// Moss lightened, for subtle fills.
  static const mossTint = Color(0xFFDDE3D5);
}
