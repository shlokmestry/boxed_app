import 'dart:typed_data';
import 'dart:math';
import 'package:rsa_encrypt/rsa_encrypt.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  static final _storage = FlutterSecureStorage();
  static final _helper = RsaKeyHelper(); 

  
  static Future<void> generateAndStoreKeyPair(String userId) async {
    final keyPair = await _helper.computeRSAKeyPair(_helper.getSecureRandom());
    final pubPem = _helper.encodePublicKeyToPemPKCS1(keyPair.publicKey as pc.RSAPublicKey);
    final privPem = _helper.encodePrivateKeyToPemPKCS1(keyPair.privateKey as pc.RSAPrivateKey);

    // Save private key securely on device
    await _storage.write(key: 'privateKey', value: privPem);

    // Save public key in Firestore
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'publicKey': pubPem,
    }, SetOptions(merge: true));
  }

  
  static Future<String?> getPrivateKey() async {
    return await _storage.read(key: 'privateKey');
  }

  static Uint8List generateAesKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }

  /// ✅ Encrypt content with AES key + random IV (returns [IV + encrypted data])
  static Uint8List encryptDataAES(Uint8List plainData, Uint8List aesKey) {
    final key = encrypt.Key(aesKey);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encryptBytes(plainData, iv: iv);
    return Uint8List.fromList(iv.bytes + encrypted.bytes); // [IV][Ciphertext]
  }

  /// ✅ Decrypt AES-encrypted content (extracts IV)
  static List<int> decryptDataAES(Uint8List encryptedData, Uint8List aesKey) {
    final iv = encrypt.IV(encryptedData.sublist(0, 16));
    final cipherText = encryptedData.sublist(16);
    final key = encrypt.Key(aesKey);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decryptBytes(encrypt.Encrypted(cipherText), iv: iv);
  }

  /// ✅ Encrypt AES capsule key using recipient's RSA public key
  static String encryptCapsuleKeyForUser(Uint8List aesKey, String userPublicKeyPem) {
    final parser = encrypt.RSAKeyParser();
    final publicKey = parser.parse(userPublicKeyPem) as pc.RSAPublicKey;
    final encrypter = encrypt.Encrypter(encrypt.RSA(publicKey: publicKey));
    return encrypter.encryptBytes(aesKey).base64;
  }

  /// ✅ Decrypt AES capsule key using current user's private RSA key
  static List<int> decryptCapsuleKey(String encryptedBase64, String privateKeyPem) {
    final parser = encrypt.RSAKeyParser();
    final privateKey = parser.parse(privateKeyPem) as pc.RSAPrivateKey;
    final encrypter = encrypt.Encrypter(encrypt.RSA(privateKey: privateKey));
    return encrypter.decryptBytes(encrypt.Encrypted.fromBase64(encryptedBase64));
  }
}
