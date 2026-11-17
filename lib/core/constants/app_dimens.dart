/// Spacing, sizing and radius tokens. Every layout uses these, no magic numbers.
abstract final class AppDimens {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Horizontal page margin, identical on every screen.
  static const double pagePadding = 20;

  /// Content is centred and capped on wide screens (tablets, desktop).
  static const double maxContentWidth = 640;

  static const double radius = 6;
  static const double radiusLarge = 10;

  static const double controlHeight = 48;
  static const double compactControlHeight = 40;
}
