import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:boxed_app/core/services/boxed_encryption_service.dart';

class CapsuleEncryption {
  /// Generate a new AES-256 key (base64)
  static Future<String> generateAESKey() async {
    final key = await BoxedEncryptionService.generateCapsuleKey();
    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  /// Encrypt memory using the BoxedEncryptionService format (AES-GCM SecretBox encoded as base64 string)
  static Future<String> encryptMemory(String plainText, String base64Key) async {
    try {
      final keyBytes = base64Decode(base64Key.trim());
      final capsuleKey = SecretKey(keyBytes);

      return await BoxedEncryptionService.encryptData(
        plainText: plainText,
        capsuleKey: capsuleKey,
      );
    } catch (e) {
      // ignore: avoid_print
      print('encryption error: $e');
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt memory produced by encryptMemory() above (AES-GCM SecretBox encoded as base64 string)
  static Future<String> decryptMemory(String encryptedText, String base64Key) async {
    try {
      final keyBytes = base64Decode(base64Key.trim());
      final capsuleKey = SecretKey(keyBytes);

      return await BoxedEncryptionService.decryptData(
        encryptedText: encryptedText.trim(),
        capsuleKey: capsuleKey,
      );
    } catch (e) {
      // ignore: avoid_print
      print('decryption error: $e');
      throw Exception('Decryption failed: $e');
    }
  }
}
