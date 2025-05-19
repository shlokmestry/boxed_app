import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:boxed_app/screens/create_capsule_screen.dart';
import 'package:boxed_app/screens/capsule_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Capsules'),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCapsuleScreen()),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: user == null
          ? const Center(child: Text("Please sign in to view capsules"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('capsules')
                  .where('memberIds', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("No capsules found."));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['name'] ?? '';
                    final description = data['description'] ?? '';
                    final unlockDate = (data['unlockDate'] as Timestamp).toDate();
                    final isUnlocked = DateTime.now().isAfter(unlockDate);

                    return CapsuleCard(
                      title: title,
                      description: description,
                      unlockDate: unlockDate,
                      isUnlocked: isUnlocked,
                      onTap: isUnlocked
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CapsuleDetailScreen(
                                    capsuleId: docs[index].id, isUnlocked: isUnlocked,
                                  ),
                                ),
                              );
                            }
                          : null,
                    );
                  },
                );
              },
            ),
    );
  }
}

class CapsuleCard extends StatelessWidget {
  final String title;
  final String description;
  final DateTime unlockDate;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const CapsuleCard({
    required this.title,
    required this.description,
    required this.unlockDate,
    required this.isUnlocked,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isUnlocked ? 1 : 0.5,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[300]),
                ),
                const SizedBox(height: 12),
                Text(
                  isUnlocked
                      ? 'Unlocked 🎉'
                      : 'Opens on ${unlockDate.toLocal().toString().split(' ')[0]}',
                  style: TextStyle(
                    color: isUnlocked ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
