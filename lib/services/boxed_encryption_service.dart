import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';

class BoxedEncryptionService {
  static final _aesGcm = AesGcm.with256bits();
  static final _pbkdf2 = Pbkdf2(
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

    return await _pbkdf2.deriveKey(
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
  // HELPERS
  // ─────────────────────────────────────────────

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
