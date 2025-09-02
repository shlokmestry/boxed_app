import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';
import 'dart:typed_data';

class CapsuleService {
  /// Creates a new encrypted capsule and stores it in Firestore
  static Future<void> createEncryptedCapsule({
    required String creatorId,
    required String name,
    required String description,
    required DateTime unlockDate,
    required List<String> memberIds, // including creator
    required Map<String, String> userPublicKeys, // userId -> PEM
  }) async {
    try {
      // Generate capsule ID
      final capsuleId =
          FirebaseFirestore.instance.collection('capsules').doc().id;

      // Generate AES key for capsule
      final Uint8List aesKey = EncryptionService.generateAesKey();

      // Encrypt AES key per user
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

      // Store capsule in Firestore with proper Timestamp fields
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
        'createdAt': Timestamp.fromDate(DateTime.now().toUtc()),
        'isLocked': true,
        'status': 'active', // You may want to track status as well
      });

      print("✅ Capsule '$name' created successfully with ID: $capsuleId");
    } catch (e, st) {
      print("❌ Error creating capsule: $e");
      print(st);
      rethrow;
    }
  }

  /// Fetches all capsules the user is a member of (for debugging)
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
