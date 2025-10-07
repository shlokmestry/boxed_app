// lib/models/collaborator_invite.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CollaboratorInvite {
  final String capsuleId;
  final String capsuleTitle;
  final String inviterUserId;
  final String inviterUsername;
  final String role;
  final DateTime unlockDate;

  CollaboratorInvite({
    required this.capsuleId,
    required this.capsuleTitle,
    required this.inviterUserId,
    required this.inviterUsername,
    required this.role,
    required this.unlockDate,
  });

  factory CollaboratorInvite.fromFirestore(
      String capsuleId, Map<String, dynamic> data) {
    return CollaboratorInvite(
      capsuleId: capsuleId,
      capsuleTitle: data['name'] ?? '',
      inviterUserId: data['creatorId'] ?? '',
      inviterUsername: data['creatorUsername'] ?? '',
      role: data['role'] ?? 'Editor',
      unlockDate:
          (data['unlockDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
