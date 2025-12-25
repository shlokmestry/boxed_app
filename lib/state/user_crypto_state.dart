import 'package:cryptography/cryptography.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';

class UserCryptoState {
  static SecretKey? _userMasterKey;

  /// MUST be called exactly once after successful login
  static Future<void> initializeForUser({
    required String userId,
    required String password,
  }) async {
    if (_userMasterKey != null) return;

    _userMasterKey =
        await BoxedEncryptionService.getOrCreateUserMasterKey(
      userId: userId,
      password: password,
    );
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
