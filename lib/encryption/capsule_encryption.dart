import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class CapsuleEncryption {
  /// Encrypt a memory string using AES key
  static String encryptMemory(String text, String base64Key) {
    final key = Key.fromBase64(base64Key);
    final iv = IV.fromLength(16); 
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(text, iv: iv);
    return encrypted.base64;
  }

  /// Decrypt memory string using AES key
  static String decryptMemory(String encryptedText, String base64Key) {
    final key = Key.fromBase64(base64Key);
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key));
    return encrypter.decrypt64(encryptedText, iv: iv);
  }

  /// Generate a new AES key (for a new capsule)
  static String generateAESKey() {
    final key = Key.fromSecureRandom(32);
    return key.base64;
  }
}
