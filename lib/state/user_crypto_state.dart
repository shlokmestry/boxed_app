import 'package:cryptography/cryptography.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';

class UserCryptoState {
  static SecretKey? _userMasterKey;

  /// Nullable accessor (does NOT throw)
  static SecretKey? get userMasterKeyOrNull => _userMasterKey;

  /// Strict accessor used where key MUST exist
  static SecretKey get userMasterKey {
    final key = _userMasterKey;
    if (key == null) {
      throw Exception('User master key not initialized');
    }
    return key;
  }

  /// LOGIN / SIGNUP ONLY (password available)
  static Future<void> initializeForUser({
    required String userId,
    required String password,
  }) async {
    _userMasterKey = await BoxedEncryptionService.getOrCreateUserMasterKey(
      userId: userId,
      password: password,
    );
  }

  /// APP STARTUP ONLY (loads persisted key; no password required)
  static Future<void> initialize(String userId) async {
    if (_userMasterKey != null) return;

    final storedKey = await BoxedEncryptionService.loadUserMasterKey(userId);
    if (storedKey == null) {
      throw Exception('User master key not found. User must log in again.');
    }

    _userMasterKey = storedKey;
  }

  /// Clear on logout
  static void clear() {
    _userMasterKey = null;
  }
}
