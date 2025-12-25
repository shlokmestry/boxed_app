import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class BoxedEncryptionService {
  static final _aesGcm = AesGcm.with256bits();
  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  // ============================
  // USER MASTER KEY (RECOVERABLE)
  // ============================

  static Future<SecretKey> deriveUserMasterKey({
    required String password,
    required String userId,
    required String salt,
  }) async {
    return await _pbkdf2.deriveKey(
      secretKey: SecretKey(password.codeUnits),
      nonce: utf8.encode('$userId:$salt'),
    );
  }

  // ============================
  // CAPSULE KEY
  // ============================

  static Future<SecretKey> generateCapsuleKey() async {
    return await _aesGcm.newSecretKey();
  }

  static Future<String> encryptCapsuleKeyForUser({
    required SecretKey capsuleKey,
    required SecretKey userMasterKey,
  }) async {
    final capsuleKeyBytes = await capsuleKey.extractBytes();

    final secretBox = await _aesGcm.encrypt(
      capsuleKeyBytes,
      secretKey: userMasterKey,
    );

    return _encodeSecretBox(secretBox);
  }

  static Future<SecretKey> decryptCapsuleKeyForUser({
    required String encryptedCapsuleKey,
    required SecretKey userMasterKey,
  }) async {
    final secretBox = _decodeSecretBox(encryptedCapsuleKey);

    final clearBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: userMasterKey,
    );

    return SecretKey(clearBytes);
  }

  // ============================
  // MEMORY ENCRYPTION
  // ============================

  static Future<String> encryptData({
    required String plainText,
    required SecretKey capsuleKey,
  }) async {
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plainText),
      secretKey: capsuleKey,
    );

    return _encodeSecretBox(secretBox);
  }

  static Future<String> decryptData({
    required String encryptedData,
    required SecretKey capsuleKey,
  }) async {
    final secretBox = _decodeSecretBox(encryptedData);

    final clearBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: capsuleKey,
    );

    return utf8.decode(clearBytes);
  }

  // ============================
  // HELPERS
  // ============================

  static String _encodeSecretBox(SecretBox box) {
    final map = {
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    return base64Encode(utf8.encode(jsonEncode(map)));
  }

  static SecretBox _decodeSecretBox(String encoded) {
    final decoded =
        jsonDecode(utf8.decode(base64Decode(encoded))) as Map<String, dynamic>;

    return SecretBox(
      base64Decode(decoded['cipherText']),
      nonce: base64Decode(decoded['nonce']),
      mac: Mac(base64Decode(decoded['mac'])),
    );
  }
}
