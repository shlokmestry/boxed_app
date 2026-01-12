import 'package:cloud_firestore/cloud_firestore.dart';

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
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final CollectionReference _capsules =
      _firestore.collection('capsules');

  /// SOLO MVP:
  /// This method is no longer used by the CreateCapsuleScreen (it writes directly),
  /// but kept here in case you want a programmatic creator later.
  static Future<CapsuleCreateResult> createEncryptedCapsule({
    required String creatorId,
    required String name,
    required String description,
    required DateTime unlockDate,
  }) async {
    try {
      final capsuleDoc = _capsules.doc();
      final capsuleId = capsuleDoc.id;

      await capsuleDoc.set({
        'capsuleId': capsuleId,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'unlockDate': Timestamp.fromDate(unlockDate.toUtc()),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // solo fields
        'emoji': '🔒',
        'backgroundId': null,
        'isSurprise': false,
      });

      return CapsuleCreateResult.success(capsuleId);
    } catch (e, st) {
      // ignore: avoid_print
      print('Error creating capsule: $e');
      // ignore: avoid_print
      print(st);
      return CapsuleCreateResult.failure(e.toString());
    }
  }

  /// Collaborator flows are unused in solo MVP; leave as no‑ops or remove later.
  static Future<void> acceptInvite({
    required String capsuleId,
    required String userId,
  }) async {
    // no-op in solo MVP
    return;
  }

  static Future<void> declineInvite({
    required String capsuleId,
    required String userId,
  }) async {
    // no-op in solo MVP
    return;
  }

  static Future<void> autoUnlockExpiredCapsules(
    String userId,
  ) async {
    // Optional: if you later want a cron-like unlock update, implement here.
    return;
  }


  /// SOLO MVP: fetch all capsules where this user is the creator.
static Future<List<Map<String, dynamic>>> fetchUserCapsules(String userId) async {
  try {
    final querySnapshot = await _capsules
        .where('creatorId', isEqualTo: userId)
        // .orderBy('createdAt', descending: true)  // Index ready, uncomment later
        .get();

    return querySnapshot.docs
        .map((doc) => {'capsuleId': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  } catch (e) {
    print('Error fetching user capsules: $e');
    return [];
  }
}


}
