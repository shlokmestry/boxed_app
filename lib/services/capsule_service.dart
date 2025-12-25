import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:boxed_app/state/user_crypto_state.dart';
import 'package:cryptography/cryptography.dart';

class CapsuleService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final CollectionReference _capsules =
      _firestore.collection('capsules');

  /// Creates an encrypted capsule.
  /// If [collaboratorUserId] is provided, capsule starts as `pending`
  /// and a collaboration request must be created separately.
  static Future<String> createEncryptedCapsule({
    required String creatorId,
    required String name,
    required String description,
    required DateTime unlockDate,
    required List<String> collaboratorIds,
    bool isSurprise = false,
  }) async {
    try {
      final capsuleRef = _capsules.doc();
      final capsuleId = capsuleRef.id;

      // Master key (already initialized at login)
      final SecretKey userMasterKey =
          UserCryptoState.userMasterKey;

      // Generate one capsule key
      final SecretKey capsuleKey =
          await BoxedEncryptionService.generateCapsuleKey();

      // Encrypt capsule key for each collaborator
      final Map<String, String> encryptedCapsuleKeys = {};
      for (final uid in collaboratorIds) {
        final encryptedKey =
            await BoxedEncryptionService.encryptCapsuleKeyForUser(
          capsuleKey: capsuleKey,
          userMasterKey: userMasterKey,
        );
        encryptedCapsuleKeys[uid] = encryptedKey;
      }

      await capsuleRef.set({
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'collaboratorIds': collaboratorIds,
        'roles': {
          for (final uid in collaboratorIds) uid: 'editor',
        },
        'unlockDate': Timestamp.fromDate(unlockDate.toUtc()),
        'capsuleKeys': encryptedCapsuleKeys,
        'status': collaboratorIds.length > 1 ? 'pending' : 'active',
        'isSurprise': isSurprise,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return capsuleId;
    } catch (e, st) {
      print('Error creating encrypted capsule: $e');
      print(st);
      rethrow;
    }
  }

  /// Automatically unlock capsules when the unlock date has passed.
  /// Called on app open / resume.
  static Future<void> autoUnlockExpiredCapsules(
    String userId,
  ) async {
    final now = Timestamp.now();

    final query = await _capsules
        .where('collaboratorIds', arrayContains: userId)
        .where('status', isEqualTo: 'active')
        .where('unlockDate', isLessThanOrEqualTo: now)
        .get();

    for (final doc in query.docs) {
      await doc.reference.update({
        'status': 'unlocked',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Fetch all capsules visible to the user
  static Future<List<Map<String, dynamic>>> fetchUserCapsules(
    String userId,
  ) async {
    try {
      final querySnapshot = await _capsules
          .where('collaboratorIds', arrayContains: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e, st) {
      print('Error fetching user capsules: $e');
      print(st);
      return [];
    }
  }
}
