import 'package:cryptography/cryptography.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';

class UserCryptoState {
  static SecretKey? _userMasterKey;

  /// OPTION A:
  /// Re-derive key silently whenever we have uid + password
  static Future<void> initializeForUser({
    required String userId,
    required String password,
  }) async {
    _userMasterKey =
        await BoxedEncryptionService.getOrCreateUserMasterKey(
      userId: userId,
      password: password,
    );
  }

  /// Accessor used everywhere else
  static SecretKey get userMasterKey {
    if (_userMasterKey == null) {
      throw Exception('User master key not initialized');
    }
    return _userMasterKey!;
  }

  /// Clear on logout (optional but correct)
  static void clear() {
    _userMasterKey = null;
  }
}
