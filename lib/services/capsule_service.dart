// capsule_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';
import 'dart:typed_data';

class CapsuleService {
  static Future<void> createEncryptedCapsule({
    required String creatorId,
    required String name,
    required String description,
    required DateTime unlockDate,
    required List<String> memberIds, // including creator
    required Map<String, String> userPublicKeys, // userId -> PEM
  }) async {
    final capsuleId = FirebaseFirestore.instance.collection('capsules').doc().id;
    final aesKey = EncryptionService.generateAesKey();

    // Encrypt AES key per user
    final Map<String, String> encryptedKeys = {};
    for (final userId in memberIds) {
      final userPem = userPublicKeys[userId];
      final encryptedKey = EncryptionService.encryptCapsuleKeyForUser(aesKey, userPem!);
      encryptedKeys[userId] = encryptedKey;
    }

    // Store capsule
    await FirebaseFirestore.instance.collection('capsules').doc(capsuleId).set({
      'capsuleId': capsuleId,
      'name': name,
      'description': description,
      'creatorId': creatorId,
      'unlockDate': unlockDate.toUtc(),
      'memberIds': memberIds,
      'capsuleKeys': encryptedKeys,
      'createdAt': DateTime.now().toUtc(),
      'isLocked': true,
    });
  }
}
