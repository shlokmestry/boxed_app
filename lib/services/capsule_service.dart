import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';
import 'dart:typed_data';
import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:boxed_app/state/user_crypto_state.dart';
import 'package:cryptography/cryptography.dart';


class CapsuleService {
  /// Creates a new encrypted capsule and stores it in Firestore
  /// If there are collaborators, set status to 'pending' to await acceptance
  
  static Future<Map<String, String>> _buildCapsuleKeysForMembers({
  required List<String> memberIds,
}) async {
  final userMasterKey = UserCryptoState.userMasterKey;

  // Generate one capsule key for this capsule
  final capsuleKey = await BoxedEncryptionService.generateCapsuleKey();

  // Encrypt capsule key separately for each member using the SAME master key
  // NOTE: This assumes same user on device creating capsule (creator) is encrypting for all.
  // We'll upgrade this in a later step so each member uses THEIR own master key.
  final capsuleKeys = <String, String>{};

  for (final uid in memberIds) {
    final enc = await BoxedEncryptionService.encryptCapsuleKeyForUser(
      capsuleKey: capsuleKey,
      userMasterKey: userMasterKey,
    );
    capsuleKeys[uid] = enc;
  }

  return capsuleKeys;
}

  static Future<void> createEncryptedCapsule({
    required String creatorId,
    required String name,
    required String description,
    required DateTime unlockDate,
    required List<String> memberIds, // including creator
    required Map<String, String> userPublicKeys, // userId -> PEM
    bool hasCollaborators = false,
  }) async {
    try {
      final capsuleId =
          FirebaseFirestore.instance.collection('capsules').doc().id;

      final Uint8List aesKey = EncryptionService.generateAesKey();

      final Map<String, String> encryptedKeys = {};
      for (final userId in memberIds) {
        final userPem = userPublicKeys[userId];
        if (userPem == null || userPem.isEmpty) {
          throw Exception(
              "Missing public key for userId: $userId — cannot create capsule.");
        }
        final encryptedKey =
            EncryptionService.encryptCapsuleKeyForUser(aesKey, userPem);
        encryptedKeys[userId] = encryptedKey;
      }

      final List<Map<String, dynamic>> collaborators = memberIds.map((userId) {
        return {
          'userId': userId,
          'accepted': userId == creatorId ? true : !hasCollaborators ? true : false,
        };
      }).toList();

      await FirebaseFirestore.instance
          .collection('capsules')
          .doc(capsuleId)
          .set({
        'capsuleId': capsuleId,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'unlockDate': Timestamp.fromDate(unlockDate.toUtc()),
        'memberIds': memberIds,
        'capsuleKeys': encryptedKeys,
        'collaborators': collaborators,
        'createdAt': Timestamp.fromDate(DateTime.now().toUtc()),
        'isLocked': true,
        'status': hasCollaborators ? 'pending' : 'active',
      });

      print("✅ Capsule '$name' created successfully with ID: $capsuleId");
    } catch (e, st) {
      print("❌ Error creating capsule: $e");
      print(st);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchUserCapsules(
      String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .where('memberIds', arrayContains: userId)
          .get();

      print("📦 Fetched ${querySnapshot.docs.length} capsules for $userId");

      final capsules = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      for (var c in capsules) {
        final unlockDate = c['unlockDate'];
        String unlockInfo = unlockDate != null
            ? unlockDate.toDate().toLocal().toString()
            : 'unknown';
        print("🔹 Capsule: ${c['name']} - Unlocks on $unlockInfo");
      }

      return capsules;
    } catch (e, st) {
      print("❌ Error fetching user capsules: $e");
      print(st);
      return [];
    }
  }
}
