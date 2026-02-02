import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:boxed_app/features/Settings/Misc/help_support_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appName = 'Boxed';
  static const String version = 'Version 1.0.0';

  // Replace these with your real links
  static const String privacyPolicyUrl = 'https://example.com/privacy';
  static const String termsUrl = 'https://example.com/terms';

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      await launch(url); // old url_launcher API
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link.'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
    }
  }

  Widget _actionCard({
    required BuildContext context,
    required String title,
    required VoidCallback onTap,
    bool external = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  external ? Icons.open_in_new : Icons.chevron_right,
                  color: const Color(0xFF6B7280),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Icon tile (matches screenshot vibe)
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined, // cube/box vibe
                  color: Colors.white,
                  size: 34,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Collaborative digital time capsules that unlock\nmeaningful memories with friends.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 22),

              // Action cards
              _actionCard(
                context: context,
                title: 'Privacy Policy',
                external: true,
                onTap: () => _openUrl(context, privacyPolicyUrl),
              ),
              _actionCard(
                context: context,
                title: 'Terms of Service',
                external: true,
                onTap: () => _openUrl(context, termsUrl),
              ),
              _actionCard(
                context: context,
                title: 'Help & Support',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                  );
                },
              ),

              const Spacer(),

              // Footer
              Text(
                version,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Made with ❤️ for memory makers',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.30),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
