/// Application-wide constants.
abstract final class AppConstants {
  static const appName = 'StockQR';

  // Default administrator, created when the database is first initialised.
  static const defaultAdminUsername = 'admin';
  static const defaultAdminPassword = 'Admin@123';
  static const defaultAdminEmail = 'admin@stockqr.local';
  static const defaultAdminName = 'Administrateur';

  // Defaults applied to every newly registered regular user.
  static const defaultMaxProducts = 50;
  static const defaultCanScan = true;
  static const defaultSubscriptionDays = 365;

  /// Prefix of the versioned QR payload: `stockqr:v1:<qr_identifier>`.
  static const qrPayloadPrefix = 'stockqr';
  static const qrPayloadVersion = 'v1';

  static const sessionKey = 'session_user_id';

  static const defaultCategories = [
    'Général',
    'Alimentaire',
    'Boissons',
    'Hygiène',
    'Papeterie',
    'Électronique',
  ];

  static const currencySymbol = 'DT';
  static const locale = 'fr_FR';
}
