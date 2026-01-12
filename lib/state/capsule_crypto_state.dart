import 'package:cryptography/cryptography.dart';

class CapsuleCryptoState {
  static final Map<String, SecretKey> _capsuleKeys = {};

  static void setCapsuleKey(String capsuleId, SecretKey key) {
    _capsuleKeys[capsuleId] = key;
  }

  /// Strict getter (throws if missing)
  static SecretKey getCapsuleKey(String capsuleId) {
    final key = _capsuleKeys[capsuleId];
    if (key == null) {
      throw Exception('Capsule key not loaded');
    }
    return key;
  }

  /// Safe getter (returns null if missing)
  static SecretKey? getCapsuleKeyOrNull(String capsuleId) {
    return _capsuleKeys[capsuleId];
  }

  static void clearCapsuleKey(String capsuleId) {
    _capsuleKeys.remove(capsuleId);
  }

  static void clearAll() {
    _capsuleKeys.clear();
  }
}
