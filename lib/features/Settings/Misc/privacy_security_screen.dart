import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacySecurityScreen extends StatelessWidget {
  /// Replace with your real support email.
  static const String supportEmail = 'support@boxed.app';

  const PrivacySecurityScreen({super.key});

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': 'Boxed — Privacy & Security',
      },
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Could not open email app');
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support email copied to clipboard.'),
            backgroundColor: Color(0xFF2A2A2A),
          ),
        );
      }
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.72),
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  Widget _bullet(String boldLead, String rest) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 14,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: '$boldLead: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: rest),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simpleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.black;
    const surface = Color(0xFF1F2937);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Privacy & Security',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privacy & Security (Boxed)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _bodyText(
                  'Boxed is a collaborative time‑capsule app where friends contribute memories (text, photos, notes, and other media) that stay sealed until a future unlock date. '
                  'Your privacy matters to us, so we design Boxed to collect only what’s needed to run the product, protect your content, and give you control over your data.',
                ),

                _sectionTitle('What Boxed collects'),
                _bullet(
                  'Account information',
                  'When you create an account, we collect basic details such as your email and profile info (e.g., display name/username and optional profile photo) so you can sign in and be recognized in shared capsules.',
                ),
                _bullet(
                  'Capsule content',
                  'We store the content you choose to upload or write—capsule titles/descriptions and memories (texts, photos, notes, and other supported media). If you collaborate with friends, your contributions appear inside that shared capsule.',
                ),
                _bullet(
                  'Collaborative metadata',
                  'To make shared capsules work, we store participation details like who is a member of a capsule, who created a memory, timestamps (created time and unlock time), and other necessary app metadata.',
                ),
                _bullet(
                  'Notifications (optional)',
                  'If you enable notifications, we store what’s needed to deliver reminders (for example, a device notification token). We use notifications to build anticipation as the unlock date approaches.',
                ),

                _sectionTitle('How we use your information'),
                _bodyText('We use your information to:'),
                const SizedBox(height: 10),
                _simpleBullet('Authenticate you and keep your account secure.'),
                _simpleBullet(
                    'Create and manage time capsules (including collaborative capsules with friends).'),
                _simpleBullet(
                    'Store your memories and show them to the right capsule members when unlocked.'),
                _simpleBullet(
                    'Send interactive reminders and product updates if you’ve opted in to notifications.'),
                _simpleBullet(
                    'Improve reliability (for example, fixing bugs and performance issues).'),

                _sectionTitle('Encryption and access control'),
                _bodyText(
                  'Boxed is built around the idea that capsules are “sealed” until the unlock date. '
                  'We protect capsule content using encryption and access controls designed so only authorized members can access capsule contents, '
                  'and unlocking happens only when the preset date/time is reached. '
                  'While no system can guarantee perfect security, we treat your memories as sensitive content and design for privacy by default.',
                ),

                _sectionTitle('Sharing and collaboration'),
                _bodyText(
                  'Shared capsules are meant for groups. If you join a capsule, the other members may see your profile name and the memories you contribute to that capsule. '
                  'You should only share capsules with people you trust, because collaboration inherently means other members can access what’s inside after the unlock.',
                ),
                const SizedBox(height: 10),
                _bodyText(
                  'We do not sell your personal information. We only share data with service providers required to operate the app (such as authentication, database/storage, and notifications), and only to the extent needed for the app to work.',
                ),

                _sectionTitle('Your choices and controls'),
                _bodyText('You can:'),
                const SizedBox(height: 10),
                _simpleBullet('Edit your profile information in the app.'),
                _simpleBullet('Control what you upload and which capsules you join.'),
                _simpleBullet(
                    'Leave a capsule (where supported) if you no longer want to participate.'),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'Request access to your data or request deletion of your account/data by contacting us at: ',
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => _emailSupport(context),
                          child: Text(
                            supportEmail,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _bodyText(
                  'If you request deletion, we’ll make reasonable efforts to remove your account data and associated content, subject to technical limitations and legal requirements (for example, content that must be retained for security, fraud prevention, or compliance).',
                ),

                _sectionTitle('Data retention'),
                _bodyText(
                  'We keep your data as long as your account is active and as needed to provide the service (including storing sealed capsules until their unlock date). '
                  'If you delete content or delete your account, we will delete or anonymize data where possible, within a reasonable timeframe.',
                ),

                _sectionTitle('Security tips'),
                _bodyText('For the best protection:'),
                const SizedBox(height: 10),
                _simpleBullet(
                    'Use a strong password and don’t reuse passwords across apps.'),
                _simpleBullet('Keep your device secured (PIN/Face ID).'),
                _simpleBullet('Only invite trusted friends to shared capsules.'),

                _sectionTitle('Updates to this notice'),
                _bodyText(
                  'As Boxed evolves (for example, adding voice notes, video, or new collaboration tools), we may update this Privacy & Security notice. '
                  'The latest version will always be available in the app.',
                ),
                const SizedBox(height: 10),
                _bodyText(
                  'If you tell me the exact stack you’re using (Firebase Auth, Firestore, Storage, Cloud Messaging) and whether you use analytics/crash reporting, I can tighten this so it’s perfectly accurate to your implementation without making it long.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
