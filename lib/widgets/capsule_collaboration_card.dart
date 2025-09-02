

import 'package:flutter/material.dart';

class CapsuleCollaborationCard extends StatelessWidget {
  final String capsuleTitle;
  final String inviterUsername;
  final String role;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final DateTime? unlockDate;

  const CapsuleCollaborationCard({
    super.key,
    required this.capsuleTitle,
    required this.inviterUsername,
    required this.role,
    required this.onAccept,
    required this.onDecline,
    this.unlockDate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$inviterUsername invited you as $role',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              capsuleTitle,
              style: textTheme.titleMedium,
            ),
            if (unlockDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Unlocks: ${unlockDate!.toLocal()}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                    child: const Text("Decline"),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    child: const Text("Accept"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
