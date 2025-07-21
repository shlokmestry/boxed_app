import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class CapsuleEncryption {
  /// Generate a new AES 256-bit key (base64)
  static String generateAESKey() {
    final key = Key.fromSecureRandom(32); // 256-bit key
    return key.base64;
  }

  /// Encrypt memory using AES-256 with a random IV
  /// Format: base64(IV + ciphertext)
  static String encryptMemory(String plainText, String base64Key) {
    try {
      final key = Key.fromBase64(base64Key.trim());
      final iv = IV.fromSecureRandom(16); // 128-bit IV

      final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // Combine IV and encrypted bytes together
      final combinedBytes = iv.bytes + encrypted.bytes;
      return base64Encode(combinedBytes);
    } catch (e) {
      print('encryption error: $e');
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt memory from base64(IV + ciphertext)
  static String decryptMemory(String encryptedText, String base64Key) {
    try {
      final key = encrypt.Key.fromBase64(base64Key.trim());
      final decodedBytes = base64Decode(encryptedText.trim());

      if (decodedBytes.length < 16) {
        throw Exception('Encrypted payload is too short to contain IV.');
      }

      // Extract IV (first 16 bytes) and ciphertext
      final iv = encrypt.IV(decodedBytes.sublist(0, 16));
      final cipher = decodedBytes.sublist(16);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: AESMode.cbc, padding: 'PKCS7'),
      );

      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(cipher),
        iv: iv,
      );

      return decrypted;
    } catch (e) {
      print('decryption error: $e');
      throw Exception('Decryption failed: $e');
    }
  }
}
