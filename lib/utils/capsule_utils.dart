
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CapsuleUtils {
  static Future<void> acceptCollaboratorInvite(String capsuleId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final capsuleRef = FirebaseFirestore.instance.collection('capsules').doc(capsuleId);

    final doc = await capsuleRef.get();
    final data = doc.data();
    if (data == null) return;

    final updatedCollaborators = (data['collaborators'] as List)
        .map((collab) {
          if (collab['uid'] == user.uid) {
            collab['accepted'] = true;
          }
          return collab;
        })
        .toList();

    // If all collaborators accepted, set 'locked'; else remain 'pending'
    final allAccepted = updatedCollaborators.every((c) => c['accepted'] == true);

    await capsuleRef.update({
      'collaborators': updatedCollaborators,
      'status': allAccepted ? 'locked' : data['status'],
    });
  }

  static Future<void> declineCollaboratorInvite(String capsuleId) async {
    await FirebaseFirestore.instance.collection('capsules').doc(capsuleId).delete();
  }
}
