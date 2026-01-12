import 'package:cryptography/cryptography.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';

class UserCryptoState {
  static SecretKey? _userMasterKey;

  /// ✅ Nullable accessor (does NOT throw)
  /// Use this in screens where you want to show a message instead of crashing.
  static SecretKey? get userMasterKeyOrNull => _userMasterKey;

  /// 🔐 LOGIN / SIGNUP ONLY
  /// Called when user enters password
  static Future<void> initializeForUser({
    required String userId,
    required String password,
  }) async {
    _userMasterKey = await BoxedEncryptionService.getOrCreateUserMasterKey(
      userId: userId,
      password: password,
    );
  }

  /// 🔐 APP STARTUP ONLY
  /// Loads previously derived key (NO password required)
  static Future<void> initialize(String userId) async {
    if (_userMasterKey != null) return;

    final storedKey = await BoxedEncryptionService.loadUserMasterKey(userId);

    if (storedKey == null) {
      throw Exception('User master key not found. User must log in again.');
    }

    _userMasterKey = storedKey;
  }

  /// 🔐 Strict accessor used where key MUST exist
  static SecretKey get userMasterKey {
    if (_userMasterKey == null) {
      throw Exception('User master key not initialized');
    }
    return _userMasterKey!;
  }

  /// 🚪 Clear on logout
  static void clear() {
    _userMasterKey = null;
  }
}
