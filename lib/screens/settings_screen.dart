import 'package:boxed_app/widgets/theme_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:boxed_app/screens/edit_profile_screen.dart';
import 'package:boxed_app/screens/delete_account_screen.dart';
import 'package:boxed_app/screens/bug_report_screen.dart';  // Bug report screen
import 'package:boxed_app/screens/faq_screen.dart';  // FAQ screen

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onBackground),
        ),
        backgroundColor: colorScheme.background,
        iconTheme: IconThemeData(color: colorScheme.primary),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("Account", style: _sectionStyle(context)),
          _buildOption(
            context,
            "Edit Profile",
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            },
          ),
          _buildOption(
            context,
            "Delete Account",
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeleteAccountScreen()));
            },
          ),
          const SizedBox(height: 30),
          Text("Appearance", style: _sectionStyle(context)),
          _buildOption(
            context,
            "App Theme",
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: colorScheme.background,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16))),
                builder: (_) => const ThemePickerSheet(),
              );
            },
          ),
          const SizedBox(height: 30),
          Text("Privacy & Security", style: _sectionStyle(context)),
          _buildOption(
            context,
            "Permissions",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Permission settings coming soon",
                    style: TextStyle(color: colorScheme.onBackground),
                  ),
                  backgroundColor: colorScheme.surface,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          Text("Support", style: _sectionStyle(context)),
          _buildOption(context, "FAQ", onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FaqScreen()),
            );
          }),
          _buildOption(context, "Report a Bug", onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BugReportScreen()),
            );
          }),
          const SizedBox(height: 30),
          Text("About", style: _sectionStyle(context)),
          _buildOption(context, "Privacy Policy", onTap: () {
            // TODO: Add Privacy Policy screen or URL link here
          }),
          const SizedBox(height: 16),
          Text(
            "Boxed v1.0.0",
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onBackground.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String label,
      {VoidCallback? onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(color: colorScheme.onBackground),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onBackground),
      onTap: onTap,
    );
  }
}

TextStyle _sectionStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall!.copyWith(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        );
