import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Salted PBKDF2-HMAC-SHA256 password hashing.
///
/// Stored format: `pbkdf2_sha256$<iterations>$<salt b64>$<hash b64>`.
/// The iteration count is stored with the hash so it can be raised later
/// without invalidating existing accounts.
class PasswordHasher {
  const PasswordHasher({this.iterations = 10000});

  final int iterations;

  static const _scheme = 'pbkdf2_sha256';
  static const _keyLength = 32; // one SHA-256 block

  String hash(String password) {
    final salt = _randomBytes(16);
    final derived = _pbkdf2(utf8.encode(password), salt, iterations);
    return '$_scheme\$$iterations\$${base64.encode(salt)}\$${base64.encode(derived)}';
  }

  bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds <= 0) return false;
    try {
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      final actual = _pbkdf2(utf8.encode(password), salt, rounds);
      return _constantTimeEquals(actual, expected);
    } on FormatException {
      return false;
    }
  }

  // Single-block PBKDF2 (the derived key is exactly one HMAC-SHA256 output).
  Uint8List _pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < _keyLength; j++) {
        result[j] ^= u[j];
      }
    }
    return Uint8List.fromList(result);
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
