import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Number and date formatting (French locale, Tunisian dinar with 3 decimals).
abstract final class Fmt {
  static final _currency = NumberFormat.currency(
    locale: AppConstants.locale,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 3,
  );
  static final _integer = NumberFormat.decimalPattern(AppConstants.locale);
  static final _date = DateFormat.yMMMd(AppConstants.locale);
  static final _dateTime = DateFormat.yMMMd(AppConstants.locale).add_Hm();
  static final _month = DateFormat.yMMMM(AppConstants.locale);
  static final _longDay = DateFormat.MMMMEEEEd(AppConstants.locale);

  static String currency(num value) => _currency.format(value);
  static String integer(num value) => _integer.format(value);
  static String date(DateTime value) => _date.format(value.toLocal());
  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());
  static String month(DateTime value) => _month.format(value.toLocal());
  static String longDay(DateTime value) => _longDay.format(value.toLocal());

  /// Parses user input such as `12,5` or `12.500`. Returns null if invalid.
  static double? parseDecimal(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Plain text version of a number for pre-filling form fields.
  static String decimalInput(double value) {
    final text = value.toStringAsFixed(3);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
