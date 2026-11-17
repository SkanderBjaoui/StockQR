import 'formatters.dart';

/// Form-field validators. Each returns an error message or null when valid.
/// The same rules are re-checked in the services, so they cannot be bypassed.
abstract final class Validators {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _usernamePattern = RegExp(r'^[A-Za-z0-9._-]{3,24}$');

  static String? required(String? value, {String label = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) return '$label est obligatoire.';
    return null;
  }

  static String? fullName(String? value) {
    final missing = required(value, label: 'Le nom complet');
    if (missing != null) return missing;
    if (value!.trim().length < 2) return 'Le nom est trop court.';
    return null;
  }

  static String? username(String? value) {
    final missing = required(value, label: "Le nom d'utilisateur");
    if (missing != null) return missing;
    if (!_usernamePattern.hasMatch(value!.trim())) {
      return '3 à 24 caractères : lettres, chiffres, « . », « _ » ou « - ».';
    }
    return null;
  }

  static String? email(String? value) {
    final missing = required(value, label: "L'adresse e-mail");
    if (missing != null) return missing;
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Adresse e-mail invalide.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Le mot de passe est obligatoire.';
    if (value.length < 8) return 'Au moins 8 caractères.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Utilisez au moins une lettre et un chiffre.';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return 'Confirmez le mot de passe.';
      if (value != original()) return 'Les mots de passe ne correspondent pas.';
      return null;
    };
  }

  static String? price(String? value, {String label = 'Le prix'}) {
    final missing = required(value, label: label);
    if (missing != null) return missing;
    final parsed = Fmt.parseDecimal(value);
    if (parsed == null) return 'Saisissez un nombre valide.';
    if (parsed < 0) return 'Le montant ne peut pas être négatif.';
    if (parsed > 1e9) return 'Montant trop élevé.';
    return null;
  }

  static String? quantity(String? value, {String label = 'La quantité'}) {
    final missing = required(value, label: label);
    if (missing != null) return missing;
    final parsed = int.tryParse(value!.trim());
    if (parsed == null) return 'Saisissez un nombre entier.';
    if (parsed < 0) return 'La valeur ne peut pas être négative.';
    if (parsed > 100000000) return 'Valeur trop élevée.';
    return null;
  }
}
