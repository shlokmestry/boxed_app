import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollaborationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Future<void> acceptRequest(String requestId) async {
    final requestRef =
        _firestore.collection('collaboration_requests').doc(requestId);

    await _firestore.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Request not found');
      }

      final data = requestSnap.data()!;
      if (data['toUserId'] != _uid) {
        throw Exception('Not authorized');
      }

      final capsuleRef =
          _firestore.collection('capsules').doc(data['capsuleDraftId']);

      transaction.update(capsuleRef, {
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(requestRef, {
        'status': 'accepted',
      });
    });
  }

  Future<void> declineRequest(String requestId) async {
    final requestRef =
        _firestore.collection('collaboration_requests').doc(requestId);

    await _firestore.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Request not found');
      }

      final data = requestSnap.data()!;
      if (data['toUserId'] != _uid) {
        throw Exception('Not authorized');
      }

      final capsuleRef =
          _firestore.collection('capsules').doc(data['capsuleDraftId']);

      transaction.update(capsuleRef, {
        'status': 'deleted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(requestRef, {
        'status': 'declined',
      });
    });
  }
}
