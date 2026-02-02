import 'package:boxed_app/core/services/boxed_encryption_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:boxed_app/features/Settings/Misc/settings_screen.dart';
import 'package:boxed_app/features/capsules/state/capsule_controller.dart';
import 'package:boxed_app/features/profile/profile_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'capsule_detail_screen.dart';
import 'create_capsule_screen.dart';

enum CapsuleFilter { all, upcoming, recentlyUnlocked }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  CapsuleFilter _selectedFilter = CapsuleFilter.all;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<CapsuleController>().loadCapsules(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case CapsuleFilter.all:
        return 'All Capsules';
      case CapsuleFilter.upcoming:
        return 'Upcoming';
      case CapsuleFilter.recentlyUnlocked:
        return 'Recently Unlocked';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Your Capsules',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ProfileAvatarButton(
              user: user,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _AddCapsuleButton(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCapsuleScreen()),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: user == null ? _signedOutEmpty(context) : _capsulesBody(context, user),
    );
  }

  Widget _signedOutEmpty(BuildContext context) {
    return const Center(
      child: Text(
        'Please sign in to view capsules',
        style: TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _capsulesBody(BuildContext context, User user) {
    final controller = context.watch<CapsuleController>();

    switch (controller.state) {
      case CapsuleLoadState.loading:
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        );

      case CapsuleLoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              controller.error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        );

      case CapsuleLoadState.empty:
        return _contentScaffold(
          context,
          capsules: const [],
          userId: user.uid,
        );

      case CapsuleLoadState.ready:
        final all = controller.capsules;
        final filtered = _applyFilters(all);

        return _contentScaffold(
          context,
          capsules: filtered,
          userId: user.uid,
        );

      case CapsuleLoadState.idle:
        return const SizedBox.shrink();
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> capsules) {
    // Apply search filter
    var filtered = _applySearch(capsules);

    // Apply category filter
    switch (_selectedFilter) {
      case CapsuleFilter.all:
        break;
      case CapsuleFilter.upcoming:
        filtered = filtered.where((c) {
          final ts = c['unlockDate'];
          final unlockDate = ts is Timestamp ? ts.toDate() : DateTime.now();
          return DateTime.now().isBefore(unlockDate);
        }).toList();
        break;
      case CapsuleFilter.recentlyUnlocked:
        filtered = filtered.where((c) {
          final ts = c['unlockDate'];
          final unlockDate = ts is Timestamp ? ts.toDate() : DateTime.now();
          return DateTime.now().isAfter(unlockDate);
        }).toList();
        break;
    }

    return filtered;
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> capsules) {
    if (_query.isEmpty) return capsules;

    return capsules.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final desc = (c['description'] ?? '').toString().toLowerCase();
      return name.contains(_query) || desc.contains(_query);
    }).toList();
  }

  Widget _contentScaffold(
    BuildContext context, {
    required List<Map<String, dynamic>> capsules,
    required String userId,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            hintText: 'Search capsules...',
          ),
          const SizedBox(height: 16),
          _FilterDropdown(
            selectedFilter: _selectedFilter,
            onChanged: (filter) {
              setState(() => _selectedFilter = filter);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _CapsulesList(
              userId: userId,
              capsules: capsules,
              emptyText: _getEmptyText(),
            ),
          ),
        ],
      ),
    );
  }

 String _getEmptyText() {
  switch (_selectedFilter) {
    case CapsuleFilter.all:
      return 'No capsules in sight… suspiciously tidy,\nisn’t it?';
    case CapsuleFilter.upcoming:
      return 'Nothing scheduled yet.\nSet an unlock date.';
    case CapsuleFilter.recentlyUnlocked:
      return 'Nothing unlocked lately.\nGive it time.';
  }
}

}

class _FilterDropdown extends StatelessWidget {
  final CapsuleFilter selectedFilter;
  final ValueChanged<CapsuleFilter> onChanged;

  const _FilterDropdown({
    required this.selectedFilter,
    required this.onChanged,
  });

  String _getLabel(CapsuleFilter filter) {
    switch (filter) {
      case CapsuleFilter.all:
        return 'All Capsules';
      case CapsuleFilter.upcoming:
        return 'Upcoming';
      case CapsuleFilter.recentlyUnlocked:
        return 'Recently Unlocked';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<CapsuleFilter>(
        value: selectedFilter,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        dropdownColor: const Color(0xFF2A2A2A),
        icon: const Icon(
          Icons.unfold_more,
          color: Color(0xFF9CA3AF),
          size: 20,
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        items: CapsuleFilter.values.map((filter) {
          return DropdownMenuItem(
            value: filter,
            child: Row(
              children: [
                if (filter == selectedFilter)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                Text(_getLabel(filter)),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _CapsulesList extends StatelessWidget {
  final String userId;
  final List<Map<String, dynamic>> capsules;
  final String emptyText;

  const _CapsulesList({
    required this.userId,
    required this.capsules,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CapsuleController>();

    if (capsules.isEmpty) {
  return Center(
    child: Text(
      emptyText,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 16,
      ),
    ),
  );
}


    return RefreshIndicator(
      onRefresh: () => controller.loadCapsules(userId),
      backgroundColor: const Color(0xFF2A2A2A),
      color: Colors.white,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: capsules.length,
        itemBuilder: (context, index) {
          final c = capsules[index];

          final title = (c['name'] ?? '').toString();

          final ts = c['unlockDate'];
          final unlockDate = ts is Timestamp ? ts.toDate() : DateTime.now();

          final isUnlocked = DateTime.now().isAfter(unlockDate);

          return _CapsuleCard(
            title: title,
            unlockDate: unlockDate,
            isUnlocked: isUnlocked,
            onTap: () {
              final capsuleId = (c['capsuleId'] ?? '').toString();
              if (capsuleId.isEmpty) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CapsuleDetailScreen(capsuleId: capsuleId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  final String title;
  final DateTime unlockDate;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const _CapsuleCard({
    required this.title,
    required this.unlockDate,
    required this.isUnlocked,
    this.onTap,
  });

  String _getTimeLabel() {
    if (isUnlocked) {
      final diff = DateTime.now().difference(unlockDate);
      if (diff.inDays >= 1) {
        return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
      }
      if (diff.inHours >= 1) {
        return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      }
      return 'Just now';
    } else {
      final diff = unlockDate.difference(DateTime.now());
      if (diff.inDays >= 1) {
        return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
      }
      if (diff.inHours >= 1) {
        return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
      }
      return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and status row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Untitled capsule' : title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : const Color(0xFF1E40AF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isUnlocked ? 'Unlocked' : 'Upcoming',
                        style: TextStyle(
                          color: isUnlocked
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Time info only
                Row(
                  children: [
                    Icon(
                      isUnlocked ? Icons.history : Icons.access_time,
                      color: const Color(0xFF9CA3AF),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getTimeLabel(),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _SearchBar({
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: Color(0xFF6B7280),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isDense: true,
                hintStyle: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () => controller.clear(),
              child: const Icon(
                Icons.close,
                color: Color(0xFF6B7280),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddCapsuleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCapsuleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const Icon(
            Icons.add,
            color: Colors.black,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  final User? user;
  final VoidCallback onTap;

  const _ProfileAvatarButton({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();
    final photoUrl = (user?.photoURL ?? '').trim();

    final initials = (displayName.isNotEmpty)
        ? displayName.characters.first.toUpperCase()
        : (email.isNotEmpty ? email.characters.first.toUpperCase() : 'U');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: photoUrl.isEmpty ? const Color(0xFF2A2A2A) : null,
          borderRadius: BorderRadius.circular(12),
          image: photoUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(photoUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: photoUrl.isEmpty
            ? Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              )
            : null,
      ),
    );
  }
}

// Unused class kept for compatibility
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}