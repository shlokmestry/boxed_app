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
<<<<<<< HEAD

  static final CollectionReference _capsules =
      _firestore.collection('capsules');

  /// SOLO MVP:
  /// This method is no longer used by the CreateCapsuleScreen (it writes directly),
  /// but kept here in case you want a programmatic creator later.
  static Future<CapsuleCreateResult> createEncryptedCapsule({
=======
  static final CollectionReference _capsules = _firestore.collection('capsules');


  static Future<String> createEncryptedCapsule({
>>>>>>> fc5ef48 (removed upload images feature)
    required String creatorId,
    required String name,
    required String description,
    required DateTime unlockDate,
<<<<<<< HEAD
  }) async {
    try {
      final capsuleDoc = _capsules.doc();
      final capsuleId = capsuleDoc.id;

      await capsuleDoc.set({
=======
    String emoji = '',
    int? backgroundId,
    bool isSurprise = false,
    String? initialNote,
  }) async {
    try {
      final capsuleRef = _capsules.doc();
      final capsuleId = capsuleRef.id;

      // Master key (must already be initialized at login / app startup)
      final SecretKey? userMasterKey = UserCryptoState.userMasterKeyOrNull;
      if (userMasterKey == null) {
        throw Exception('Master key missing. Please log in again.');
      }

      // Generate capsule key (used to encrypt memories/notes)
      final SecretKey capsuleKey =
          await BoxedEncryptionService.generateCapsuleKey();

      // Encrypt capsule key for the creator (stored in Firestore)
      final String encryptedCapsuleKey =
          await BoxedEncryptionService.encryptCapsuleKeyForUser(
        capsuleKey: capsuleKey,
        userMasterKey: userMasterKey,
      );

      await capsuleRef.set({
>>>>>>> fc5ef48 (removed upload images feature)
        'capsuleId': capsuleId,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'unlockDate': Timestamp.fromDate(unlockDate.toUtc()),
<<<<<<< HEAD
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
=======
        'capsuleKeys': {creatorId: encryptedCapsuleKey}, // encrypted SecretBox
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'emoji': emoji,
        'backgroundId': backgroundId,
        'isSurprise': isSurprise,
      });

      // Optional initial note (encrypted) as a memory doc
      final note = (initialNote ?? '').trim();
      if (note.isNotEmpty) {
        final encryptedNote = await BoxedEncryptionService.encryptData(
          plainText: note,
          capsuleKey: capsuleKey,
        );

        await capsuleRef.collection('memories').add({
          'type': 'text',
          'content': encryptedNote,
          'createdBy': creatorId,
          'createdAt': FieldValue.serverTimestamp(),
          'isEncrypted': true,
        });
      }

      return capsuleId;
    } catch (e, st) {
      // ignore: avoid_print
      print("Error creating capsule: $e");
>>>>>>> fc5ef48 (removed upload images feature)
      // ignore: avoid_print
      print(st);
      return CapsuleCreateResult.failure(e.toString());
    }
  }

<<<<<<< HEAD
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
=======

  static Future<void> autoUnlockExpiredCapsules(String creatorId) async {
    return;
  }

  /// SOLO MVP
  /// Fetch all capsules owned by this user.
  static Future<List<Map<String, dynamic>>> fetchUserCapsules(
    String creatorId,
  ) async {
    try {
      final querySnapshot =
          await _capsules.where('creatorId', isEqualTo: creatorId).get();

      return querySnapshot.docs
          .map((doc) => {'capsuleId': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e, st) {
      // ignore: avoid_print
      print("Error fetching user capsules: $e");
      // ignore: avoid_print
      print(st);
      return [];
    }
>>>>>>> fc5ef48 (removed upload images feature)
  }
}


}
