import 'package:cloud_firestore/cloud_firestore.dart';

/// Explicit result model so UI can react correctly.
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

  static final CollectionReference<Map<String, dynamic>> _capsules =
      _firestore.collection('capsules');

  /// SOLO MVP:
  /// CreateCapsuleScreen writes directly, but this is kept for future programmatic creation.
  static Future<CapsuleCreateResult> createEncryptedCapsule({
    required String creatorId,
    required String name,
    required String description,
    required DateTime unlockDate,
    String emoji = '🔒',
    int? backgroundId,
    bool isSurprise = false,
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
        'emoji': emoji,
        'backgroundId': backgroundId,
        'isSurprise': isSurprise,
      });

      return CapsuleCreateResult.success(capsuleId);
    } catch (e) {
      // ignore: avoid_print
      print('Error creating capsule: $e');
      return CapsuleCreateResult.failure(e.toString());
    }
  }

  /// SOLO MVP: fetch all capsules where this user is the creator.
  static Future<List<Map<String, dynamic>>> fetchUserCapsules(
    String userId,
  ) async {
    try {
      final querySnapshot =
          await _capsules.where('creatorId', isEqualTo: userId).get();

      return querySnapshot.docs
          .map((doc) => {'capsuleId': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching user capsules: $e');
      return [];
    }
  }

  /// SOLO MVP: no server-side unlock mutation needed (UI checks unlockDate).
  static Future<void> autoUnlockExpiredCapsules(String userId) async {
    return;
  }
}
