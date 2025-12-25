import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'capsule_detail_screen.dart';
import '../services/capsule_service.dart';

class CollaboratorInvitesScreen extends StatefulWidget {
  const CollaboratorInvitesScreen({super.key});

  @override
  State<CollaboratorInvitesScreen> createState() =>
      _CollaboratorInvitesScreenState();
}

class _CollaboratorInvitesScreenState extends State<CollaboratorInvitesScreen> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;



  Stream<List<QueryDocumentSnapshot>> _pendingInvitesStream() {
    return FirebaseAuth.instance.authStateChanges().switchMap((user) {
      if (user == null) {
        return const Stream<List<QueryDocumentSnapshot>>.empty();
      }

      return FirebaseFirestore.instance
          .collection('capsules')
          .where('status', isEqualTo: 'pending')
          .where('memberIds', arrayContains: user.uid)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final collaborators =
              (data['collaborators'] as List?) ?? [];

          final myCollab = collaborators
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (c) => c['uid'] == user.uid,
                orElse: () => {},
              );

          return myCollab.isNotEmpty && myCollab['accepted'] == false;
        }).toList();
      });
    });
  }

  

  Future<void> _acceptInvite(
    BuildContext context,
    QueryDocumentSnapshot capsuleDoc,
  ) async {
    final bool? editNow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      await CapsuleService.acceptInvite(
        capsuleDoc.id,
        currentUser!.uid,
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
                CapsuleDetailScreen(capsuleId: capsuleDoc.id),
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
    QueryDocumentSnapshot capsuleDoc,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline invite?'),
        content: const Text(
          'Declining will permanently delete this capsule for everyone.',
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
      await CapsuleService.declineInvite(capsuleDoc.id);

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
      appBar: AppBar(
        title: const Text('Collaborators'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _pendingInvitesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No collaboration invites'),
                  );
                }

                final docs = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data =
                        docs[index].data() as Map<String, dynamic>;

                    final capsuleTitle =
                        data['name'] ?? 'Untitled Capsule';

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
                              'You’ve been invited to collaborate on:',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              capsuleTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _declineInvite(
                                      context,
                                      docs[index],
                                    ),
                                    child:
                                        const Text('Decline'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _acceptInvite(
                                      context,
                                      docs[index],
                                    ),
                                    child:
                                        const Text('Accept'),
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
            ),
    );
  }
}
