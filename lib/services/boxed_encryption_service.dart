import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';

class BoxedEncryptionService {
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  // ─────────────────────────────────────────────
  // USER MASTER KEY (DERIVED + RECOVERABLE)
  // ─────────────────────────────────────────────

  static Future<SecretKey> getOrCreateUserMasterKey({
    required String userId,
    required String password,
  }) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final data = userDoc.data();
    if (data == null || data['encryptionSalt'] == null) {
      throw Exception('Encryption salt missing for user');
    }

    final salt = data['encryptionSalt'] as String;

    return _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode('$userId:$salt'),
    );
  }

  // ─────────────────────────────────────────────
  // CAPSULE KEY
  // ─────────────────────────────────────────────

  static Future<SecretKey> generateCapsuleKey() async {
    return _aesGcm.newSecretKey();
  }

  static Future<String> encryptCapsuleKeyForUser({
    required SecretKey capsuleKey,
    required SecretKey userMasterKey,
  }) async {
    final bytes = await capsuleKey.extractBytes();

    final secretBox = await _aesGcm.encrypt(
      bytes,
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

  // ─────────────────────────────────────────────
  // MEMORY / NOTE ENCRYPTION
  // ─────────────────────────────────────────────

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
    required String encryptedText,
    required SecretKey capsuleKey,
  }) async {
    final secretBox = _decodeSecretBox(encryptedText);

    final clearBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: capsuleKey,
    );

    return utf8.decode(clearBytes);
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  /// Encodes a SecretBox into a single base64 string containing:
  /// nonce + ciphertext + mac
  static String _encodeSecretBox(SecretBox box) {
    final map = <String, String>{
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
      base64Decode(decoded['cipherText'] as String),
      nonce: base64Decode(decoded['nonce'] as String),
      mac: Mac(base64Decode(decoded['mac'] as String)),
    );
  }
}
