import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';

class EncryptionService {
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Random _rng = Random.secure();

  /// Generates a random 32-byte AES key.
  static Uint8List generateAesKey() {
    return Uint8List.fromList(List<int>.generate(32, (_) => _rng.nextInt(256)));
  }

  /// Encrypt bytes using AES-GCM.
  ///
  /// Output format (binary): [nonce(12 bytes)] + [cipherText(N)] + [mac(16 bytes)]
  static Future<Uint8List> encryptDataAES(
    Uint8List plainData,
    Uint8List aesKey,
  ) async {
    if (aesKey.length != 32) {
      throw Exception('AES key must be 32 bytes (256-bit).');
    }

    final nonce = Uint8List.fromList(List<int>.generate(12, (_) => _rng.nextInt(256)));
    final secretKey = SecretKey(aesKey);

    final box = await _aesGcm.encrypt(
      plainData,
      secretKey: secretKey,
      nonce: nonce,
    );

    return Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// Decrypt bytes produced by encryptDataAES().
  static Future<Uint8List> decryptDataAES(
    Uint8List encryptedData,
    Uint8List aesKey,
  ) async {
    if (aesKey.length != 32) {
      throw Exception('AES key must be 32 bytes (256-bit).');
    }
    if (encryptedData.length < 12 + 16) {
      throw Exception('Encrypted payload too short.');
    }

    final nonce = encryptedData.sublist(0, 12);
    final macBytes = encryptedData.sublist(encryptedData.length - 16);
    final cipherText = encryptedData.sublist(12, encryptedData.length - 16);

    final box = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clear = await _aesGcm.decrypt(
      box,
      secretKey: SecretKey(aesKey),
    );

    return Uint8List.fromList(clear);
  }

  /// Encrypt (wrap) a capsule AES key for storage using the user's master key.
  ///
  /// Returns a Firestore-safe String (SecretBox JSON base64) via BoxedEncryptionService.
  static Future<String> encryptCapsuleKeyForUser({
    required Uint8List capsuleAesKey,
    required SecretKey userMasterKey,
  }) async {
    if (capsuleAesKey.length != 32) {
      throw Exception('Capsule key must be 32 bytes (256-bit).');
    }

    return BoxedEncryptionService.encryptCapsuleKeyForUser(
      capsuleKey: SecretKey(capsuleAesKey),
      userMasterKey: userMasterKey,
    );
  }

  /// Decrypt (unwrap) a capsule AES key from storage using the user's master key.
  ///
  /// Returns the raw 32-byte AES key.
  static Future<Uint8List> decryptCapsuleKeyForUser({
    required String encryptedCapsuleKey,
    required SecretKey userMasterKey,
  }) async {
    final key = await BoxedEncryptionService.decryptCapsuleKeyForUser(
      encryptedCapsuleKey: encryptedCapsuleKey,
      userMasterKey: userMasterKey,
    );

    final bytes = await key.extractBytes();
    return Uint8List.fromList(bytes);
  }
}
