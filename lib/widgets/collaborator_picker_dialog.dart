import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CollaboratorPickerDialog extends StatefulWidget {
  const CollaboratorPickerDialog({super.key});

  @override
  State<CollaboratorPickerDialog> createState() => _CollaboratorPickerDialogState();
}

class _CollaboratorPickerDialogState extends State<CollaboratorPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedCollaborators = [];
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchUsers(query.trim());
    });
  }

  Future<void> _searchUsers(String keyword) async {
    if (keyword.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: keyword)
        .where('username', isLessThanOrEqualTo: keyword + '\uf8ff')
        .limit(10)
        .get();

    setState(() {
      _searchResults = querySnapshot.docs
          .map((doc) => {
                'userId': doc.id,
                'username': doc['username'] ?? '',
                'email': doc['email'] ?? '',
                'photoUrl': doc['photoUrl'] ?? '',
                'role': 'Editor',
              })
          .toList();
    });
  }

  void _addCollaborator(Map<String, dynamic> user) {
    final alreadyExists = _selectedCollaborators.any((u) => u['userId'] == user['userId']);
    if (!alreadyExists) {
      setState(() {
        _selectedCollaborators.add(user);
        _searchController.clear();
        _searchResults = [];
      });
    }
  }

  void _removeCollaborator(String userId) {
    setState(() {
      _selectedCollaborators.removeWhere((u) => u['userId'] == userId);
    });
  }

  void _setRole(String userId, String role) {
    setState(() {
      final index = _selectedCollaborators.indexWhere((u) => u['userId'] == userId);
      if (index != -1) {
        _selectedCollaborators[index]['role'] = role;
      }
    });
  }

  void _done() {
    Navigator.of(context).pop(_selectedCollaborators); // Pass collaborators back
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add Collaborators", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),

            // Search Field
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search username or email',
                fillColor: colorScheme.background,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),

            // User Search Results
            if (_searchResults.isNotEmpty)
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.surfaceVariant,
                ),
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (_, i) {
                    final user = _searchResults[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (user['photoUrl']?.isNotEmpty ?? false)
                            ? NetworkImage(user['photoUrl'])
                            : null,
                        child: (user['photoUrl'] == null || user['photoUrl'].isEmpty)
                            ? Text(user['username'][0].toUpperCase())
                            : null,
                      ),
                      title: Text(user['username']),
                      subtitle: Text(user['email']),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => _addCollaborator(user),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Selected Collaborator List (ListTile style)
            if (_selectedCollaborators.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Selected Collaborators:"),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _selectedCollaborators.length,
                itemBuilder: (context, index) {
                  final c = _selectedCollaborators[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      leading: CircleAvatar(
                        backgroundImage: (c['photoUrl']?.isNotEmpty ?? false)
                            ? NetworkImage(c['photoUrl'])
                            : null,
                        child: (c['photoUrl'] == null || c['photoUrl'].isEmpty)
                            ? Text(c['username'][0].toUpperCase())
                            : null,
                      ),
                      title: Text(c['username']),
                      subtitle: Text(c['email']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<String>(
                            value: c['role'],
                            dropdownColor: colorScheme.surface,
                            underline: const SizedBox(),
                            borderRadius: BorderRadius.circular(8),
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                            ),
                            items: ['Viewer', 'Editor'].map((r) {
                              return DropdownMenuItem(
                                value: r,
                                child: Text(r),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _setRole(c['userId'], value);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeCollaborator(c['userId']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _done,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: colorScheme.primary,
                ),
                child: const Text("Done"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
