import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:boxed_app/state/user_crypto_state.dart';
import 'package:cryptography/cryptography.dart';

/// Explicit result model so UI can react correctly
class CapsuleCreateResult {
  final bool success;
  final String? capsuleId;
  final String? error;

  CapsuleCreateResult.success(this.capsuleId)
      : success = true,
        error = null;

  CapsuleCreateResult.failure(this.error)
      : success = false,
        capsuleId = null;
}

class CapsuleService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final CollectionReference _capsules =
      _firestore.collection('capsules');

  static Future<CapsuleCreateResult> createEncryptedCapsule({
    required String creatorId,
    required String name,
    required String description,
    required DateTime unlockDate,
    required List<String> memberIds,
    required bool hasCollaborators,
  }) async {
    try {
      final capsuleDoc = _capsules.doc();
      final capsuleId = capsuleDoc.id;

      // Ensure crypto state exists
      final SecretKey? userMasterKey =
          UserCryptoState.userMasterKey;

      if (userMasterKey == null) {
        return CapsuleCreateResult.failure(
          'Encryption not initialized. Please re-login.',
        );
      }

      // Generate capsule key
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

      // Build collaborator state
      final collaborators = memberIds.map((uid) {
        return {
          'uid': uid,
          'accepted': uid == creatorId ? true : !hasCollaborators,
        };
      }).toList();

      await capsuleDoc.set({
        'capsuleId': capsuleId,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'unlockDate': Timestamp.fromDate(unlockDate.toUtc()),
        'memberIds': memberIds,
        'capsuleKeys': capsuleKeys,
        'collaborators': collaborators,
        'createdAt': FieldValue.serverTimestamp(),
        'status': hasCollaborators ? 'pending' : 'locked',
      });

      return CapsuleCreateResult.success(capsuleId);
    } catch (e, st) {
      print('Error creating capsule: $e');
      print(st);
      return CapsuleCreateResult.failure(e.toString());
    }
  }

  static Future<void> acceptInvite({
    required String capsuleId,
    required String userId,
  }) async {
    final ref = _capsules.doc(capsuleId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Capsule does not exist');
      }

      final data = snap.data() as Map<String, dynamic>;
      final collaborators =
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


  static Future<void> declineInvite({
    required String capsuleId,
    required String userId,
  }) async {
    final ref = _capsules.doc(capsuleId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final collaborators =
          List<Map<String, dynamic>>.from(data['collaborators']);

      for (final c in collaborators) {
        if (c['uid'] == userId) {
          c['accepted'] = false;
        }
      }

      tx.update(ref, {
        'collaborators': collaborators,
        'status': 'declined',
      });
    });
  }

  static Future<void> autoUnlockExpiredCapsules(
    String userId,
  ) async {
    final now = Timestamp.now();

    final query = await _capsules
        .where('memberIds', arrayContains: userId)
        .where('status', isEqualTo: 'locked')
        .where('unlockDate', isLessThanOrEqualTo: now)
        .get();

    for (final doc in query.docs) {
      await doc.reference.update({
        'status': 'unlocked',
      });
    }
  }

  static Future<List<Map<String, dynamic>>> fetchUserCapsules(
    String userId,
  ) async {
    try {
      final querySnapshot = await _capsules
          .where('memberIds', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e, st) {
      print('Error fetching user capsules: $e');
      print(st);
      return [];
    }
  }
}
