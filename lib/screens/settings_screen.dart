import 'package:flutter/material.dart';
import 'package:boxed_app/screens/edit_profile_screen.dart';
import 'package:boxed_app/screens/delete_account_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Account", style: _sectionStyle),
          _buildOption(
            context,
            "Edit Profile",
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            },
          ),
          _buildOption(
            context,
            "Delete Account",
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DeleteAccountScreen()));
            },
          ),

          const SizedBox(height: 30),
          const Text("Appearance", style: _sectionStyle),
          _buildOption(
            context,
            "App Theme",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Theme toggle coming soon")),
              );
            },
          ),

          const SizedBox(height: 30),
          const Text("Privacy & Security", style: _sectionStyle),
          _buildOption(
            context,
            "Permissions",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Permission settings coming soon")),
              );
            },
          ),

          const SizedBox(height: 30),
          const Text("Support", style: _sectionStyle),
          _buildOption(context, "FAQ", onTap: () {}),
          _buildOption(context, "Contact Support", onTap: () {}),
          _buildOption(context, "Report a Bug", onTap: () {}),

          const SizedBox(height: 30),
          const Text("About", style: _sectionStyle),
          _buildOption(context, "Privacy Policy", onTap: () {}),
          const SizedBox(height: 16),
          Text(
            "Boxed v1.0.0",
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String label, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white),
      onTap: onTap,
    );
  }
}

const _sectionStyle = TextStyle(
  color: Colors.white70,
  fontSize: 14,
  fontWeight: FontWeight.bold,
);
