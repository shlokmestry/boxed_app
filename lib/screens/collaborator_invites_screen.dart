import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/collaboration_service.dart';
import 'capsule_detail_screen.dart';

class CollaboratorInvitesScreen extends StatefulWidget {
  const CollaboratorInvitesScreen({super.key});

  @override
  State<CollaboratorInvitesScreen> createState() =>
      _CollaboratorInvitesScreenState();
}

class _CollaboratorInvitesScreenState
    extends State<CollaboratorInvitesScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final CollaborationService _collaborationService =
      CollaborationService();

  bool _isLoading = false;

  Stream<QuerySnapshot> _pendingInvitesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('collaboration_requests')
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> _acceptInvite(
  BuildContext context,
  String requestId,
  String capsuleId,
  bool isViewerRole,
) async {

   final bool? editNow = isViewerRole
    ? false
    : await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Edit Capsule'),
          content: const Text(
            'You accepted the invite. Do you want to edit this capsule now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Edit now'),
            ),
          ],
        ),
      );


    setState(() => _isLoading = true);

    try {
      await _collaborationService.acceptRequest(
        requestId: requestId,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collaboration started')),
      );

      if (editNow == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CapsuleDetailScreen(capsuleId: capsuleId),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting invite: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _declineInvite(
    BuildContext context,
    String requestId,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline invite?'),
        content: const Text(
          'Declining will permanently delete this capsule.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _collaborationService.declineRequest(
        requestId: requestId,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite declined')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining invite: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collaborators')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _pendingInvitesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No collaboration invites'),
                  );
                }

                final requests = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request =
                        requests[index].data()
                            as Map<String, dynamic>;

                    final requestId = requests[index].id;
                    final capsuleId =
                        request['capsuleDraftId'] as String;
                    final fromUserId =
                        request['fromUserId'] as String;
                    final inviterName = (request['fromUserName'] ?? 'Someone') as String;
final role = (request['role'] ?? 'editor') as String;
final isViewer = role == 'viewer';


                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('capsules')
                          .doc(capsuleId)
                          .get(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const SizedBox();
                        }

                        final capsule =
                            snap.data!.data()
                                as Map<String, dynamic>;

                        return Card(
                          margin:
                              const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  capsule['name'] ??
                                      'Untitled Capsule',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Invited by  $inviterName',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _declineInvite(
                                          context,
                                          requestId,
                                        ),
                                        child: const Text(
                                            'Decline'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                           _acceptInvite(context, requestId, capsuleId, isViewer),

                                        child: const Text(
                                            'Accept'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
