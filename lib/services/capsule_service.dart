import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:boxed_app/state/user_crypto_state.dart';
import 'package:cryptography/cryptography.dart';

class CapsuleService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final CollectionReference _capsules =
      _firestore.collection('capsules');


  static Future<void> createEncryptedCapsule({
    required String creatorId,
    required String name,
    required String description,
    required DateTime unlockDate,
    required List<String> memberIds, // including creator
    required bool hasCollaborators,
  }) async {
    try {
      final capsuleId = _capsules.doc().id;

      // Master key (already initialized at login)
      final SecretKey userMasterKey =
          UserCryptoState.userMasterKey;

      // Generate one capsule key
      final SecretKey capsuleKey =
          await BoxedEncryptionService.generateCapsuleKey();

      // Encrypt capsule key for each member
      final Map<String, String> capsuleKeys = {};
      for (final uid in memberIds) {
        final encryptedKey =
            await BoxedEncryptionService.encryptCapsuleKeyForUser(
          capsuleKey: capsuleKey,
          userMasterKey: userMasterKey,
        );
        capsuleKeys[uid] = encryptedKey;
      }

      // Build collaborator list
      final List<Map<String, dynamic>> collaborators =
          memberIds.map((uid) {
        return {
          'uid': uid,
          'accepted': uid == creatorId ? true : !hasCollaborators,
        };
      }).toList();

      await _capsules.doc(capsuleId).set({
        'capsuleId': capsuleId,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'unlockDate': Timestamp.fromDate(unlockDate.toUtc()),
        'memberIds': memberIds,
        'capsuleKeys': capsuleKeys,
        'collaborators': collaborators,
        'createdAt': Timestamp.fromDate(DateTime.now().toUtc()),
        'status': hasCollaborators ? 'pending' : 'locked',
      });

      print("Capsule '$name' created ($capsuleId)");
    } catch (e, st) {
      print("Error creating capsule: $e");
      print(st);
      rethrow;
    }
  }

 
  static Future<void> acceptInvite(
    String capsuleId,
    String userId,
  ) async {
    final ref = _capsules.doc(capsuleId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Capsule does not exist');
      }

      final data = snap.data() as Map<String, dynamic>;
      final List<Map<String, dynamic>> collaborators =
          List<Map<String, dynamic>>.from(data['collaborators']);

      for (final c in collaborators) {
        if (c['uid'] == userId) {
          c['accepted'] = true;
        }
      }

      final bool allAccepted =
          collaborators.every((c) => c['accepted'] == true);

      tx.update(ref, {
        'collaborators': collaborators,
        'status': allAccepted ? 'locked' : 'pending',
      });
    });
  }

  static Future<void> declineInvite(String capsuleId) async {
    // Business rule: any decline deletes capsule
    await _capsules.doc(capsuleId).delete();
  }


  static Future<List<Map<String, dynamic>>> fetchUserCapsules(
      String userId) async {
    try {
      final querySnapshot = await _capsules
          .where('memberIds', arrayContains: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e, st) {
      print("❌ Error fetching user capsules: $e");
      print(st);
      return [];
    }
  }
}
