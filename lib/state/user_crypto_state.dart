import 'package:cryptography/cryptography.dart';

class UserCryptoState {
  static SecretKey? _userMasterKey;

  static void setUserMasterKey(SecretKey key) {
    _userMasterKey = key;
  }

  static SecretKey get userMasterKey {
    if (_userMasterKey == null) {
      throw Exception('User master key not initialized');
    }
    return _userMasterKey!;
  }

  static void clear() {
    _userMasterKey = null;
  }
}
