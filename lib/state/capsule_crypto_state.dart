import 'package:cryptography/cryptography.dart';

class CapsuleCryptoState {
  static final Map<String, SecretKey> _capsuleKeys = {};

  static void setCapsuleKey(String capsuleId, SecretKey key) {
    _capsuleKeys[capsuleId] = key;
  }

  static SecretKey getCapsuleKey(String capsuleId) {
    final key = _capsuleKeys[capsuleId];
    if (key == null) {
      throw Exception('Capsule key not loaded');
    }
    return key;
  }

  static void clearCapsuleKey(String capsuleId) {
    _capsuleKeys.remove(capsuleId);
  }

  static void clearAll() {
    _capsuleKeys.clear();
  }
}
