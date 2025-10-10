import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'capsule_detail_screen.dart';

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
          final data = doc.data();
          final collaborators = (data['collaborators'] as List?) ?? [];
          final myCollab = collaborators.cast<Map>().firstWhere(
                (c) => (c['userId'] ?? '') == user.uid,
                orElse: () => {},
              );
          return myCollab.isNotEmpty && myCollab['accepted'] == false;
        }).toList();
      });
    });
  }

  Stream<List<QueryDocumentSnapshot>> _recentDeclinedInvitesStream() {
    return FirebaseAuth.instance.authStateChanges().switchMap((user) {
      if (user == null) {
        return const Stream<List<QueryDocumentSnapshot>>.empty();
      }
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));
      return FirebaseFirestore.instance
          .collection('capsules')
          .where('status', isEqualTo: 'declined')
          .where('creatorId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.where((doc) {
          final data = doc.data();
          final declinedBy = data['declinedBy'];
          if (declinedBy == null || declinedBy['timestamp'] == null) return false;
          final declinedAt = (declinedBy['timestamp'] as Timestamp).toDate();
          return declinedAt.isAfter(cutoff);
        }).toList();
      });
    });
  }

  Future<void> _acceptInvite(
      BuildContext context, QueryDocumentSnapshot capsuleDoc) async {
    // 1. Show dialog BEFORE updating Firestore
    final bool? editNow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Capsule'),
        content: const Text(
            'You accepted the invite. Do you want to edit this capsule now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    setState(() {
      _isLoading = true;
    });
    final capsuleRef =
        FirebaseFirestore.instance.collection('capsules').doc(capsuleDoc.id);
    final capsuleData = capsuleDoc.data() as Map<String, dynamic>;
    List<dynamic> collaborators = (capsuleData['collaborators'] as List<dynamic>)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();

    for (var collab in collaborators) {
      if (collab['userId'] == currentUser?.uid) {
        collab['accepted'] = true;
        break;
      }
    }

    final allAccepted = collaborators.every((c) => c['accepted'] == true);

    final Map<String, dynamic> updateMap = {'collaborators': collaborators};
    if (allAccepted) {
      updateMap['status'] = 'active';
    }
    if (capsuleData.containsKey('declinedBy')) {
      updateMap['declinedBy'] = FieldValue.delete();
    }

    try {
      await capsuleRef.update(updateMap);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Collaboration started!")),
        );

        if (editNow == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CapsuleDetailScreen(capsuleId: capsuleDoc.id)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error accepting invite: $e")),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _declineInvite(
      BuildContext context, QueryDocumentSnapshot capsuleDoc) async {
    setState(() {
      _isLoading = true;
    });
    final capsuleRef =
        FirebaseFirestore.instance.collection('capsules').doc(capsuleDoc.id);
    final capsuleData = capsuleDoc.data() as Map<String, dynamic>;

    List<dynamic> collaborators = (capsuleData['collaborators'] as List<dynamic>)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();

    for (var collab in collaborators) {
      if (collab['userId'] == currentUser?.uid) {
        collab['accepted'] = false;
        collab['declined'] = true;
        break;
      }
    }

    try {
      await capsuleRef.update({
        'status': 'declined',
        'collaborators': collaborators,
        'declinedBy': {
          'userId': currentUser?.uid,
          'username': currentUser?.displayName ?? "",
          'timestamp': FieldValue.serverTimestamp(),
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invite declined.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error declining invite: $e")),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Collaborators"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<QueryDocumentSnapshot>>(
                    stream: _pendingInvitesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text("No collaboration invites."));
                      }

                      final docs = snapshot.data!;
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final creator = data['creatorUsername'] ?? "Someone";
                          final capsuleTitle = data['name'] ?? "Untitled Capsule";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$creator is inviting you to collaborate on:",
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    capsuleTitle,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _declineInvite(context, docs[index]),
                                          child: const Text("Decline"),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await _acceptInvite(context, docs[index]);
                                          },
                                          child: const Text("Accept"),
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
                ),
                StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _recentDeclinedInvitesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: snapshot.data!.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final declinedBy = data['declinedBy'];
                        final declinedUsername = declinedBy?['username'] ?? 'Unknown';
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Card(
                            color: Colors.red.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                "$declinedUsername decided not to join this capsule party. Maybe try creating a new one?",
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
