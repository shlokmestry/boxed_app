import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  // Define categories and their questions
  static const Map<String, List<_FaqItem>> faqCategories = {
    "General Usage": [
      _FaqItem(
        question: "What is Boxed?",
        answer:
            "Boxed is a secure time capsule app that lets you save memories and messages to be unlocked at a future date.",
      ),
      _FaqItem(
        question: "How do I create a new capsule?",
        answer:
            "Tap the + button on the home screen, fill in capsule details like name, description, unlock date, and add collaborators.",
      ),
      _FaqItem(
        question: "How do time capsules work?",
        answer:
            "Your capsules are locked until the unlock date. After that, you and collaborators can access the stored content.",
      ),
    ],
    "Collaboration": [
      _FaqItem(
        question: "How do I invite collaborators?",
        answer:
            "During capsule creation, add users by their email or user ID. Collaborators receive invites to accept before accessing the capsule.",
      ),
      _FaqItem(
        question: "What does \"Pending collaborators acceptance\" mean?",
        answer:
            "This means some collaborators have been invited but haven’t accepted the invitation yet. The capsule remains locked or limited until all invited collaborators accept or decline their invites.",
      ),
      _FaqItem(
        question: "Can collaborators edit capsule contents?",
        answer:
            "Yes, once a collaborator accepts an invite, they can add or edit memories in the capsule, such as notes or photos, depending on the access permissions.",
      ),
    ],
    "Privacy & Security": [
      _FaqItem(
        question: "Is my data encrypted?",
        answer:
            "All capsule contents are encrypted end-to-end on your device before being uploaded. Only you and your collaborators with the encryption keys can decrypt and view the content, ensuring your memories remain private and safe.",
      ),
      _FaqItem(
        question: "Who can see my capsules?",
        answer:
            "Only you and collaborators you invite can see your capsules. Collaborators must accept their invites to gain access. Capsules are encrypted to prevent unauthorized access.",
      ),
    ],
    "Troubleshooting": [
      _FaqItem(
        question: "Why can’t I see my capsules?",
        answer:
            "Common reasons include not being signed in, no capsules created yet, or being invited to capsules but having pending acceptance on collaborator invites. Check your account status and invite notifications.",
      ),
      _FaqItem(
        question: "What to do if I forget my password?",
        answer:
            "Use the account login screen’s \"Forgot Password\" feature to reset your password via email. Follow the instructions sent to your registered email address.",
      ),
      _FaqItem(
        question: "App is not working correctly. How can I get help?",
        answer:
            "You can report issues or bugs directly through the app’s “Report a Bug” feature in Settings. For additional support, contact options will be available soon.",
      ),
    ],
    "Account & Settings": [
      _FaqItem(
        question: "How do I delete my account?",
        answer:
            "In Settings, navigate to “Delete Account.” Follow the prompts to permanently delete your account and all associated capsule data. This action is irreversible.",
      ),
      _FaqItem(
        question: "Can I change my profile details later?",
        answer:
            "Yes, you can update your profile info such as username, avatar, and bio anytime in the “Edit Profile” section of Settings.",
      ),
    ],
    "Miscellaneous": [
      _FaqItem(
        question: "How to change app theme?",
        answer:
            "Go to Settings → Appearance → App Theme to toggle between Light, Dark, or System default themes.",
      ),
      _FaqItem(
        question: "Will Boxed work offline?",
        answer:
            "Some features may work offline, such as viewing previously unlocked capsules. However, network connectivity is needed to sync new capsules, send invites, or upload content.",
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final categoryTitles = faqCategories.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
        backgroundColor: colorScheme.background,
        iconTheme: IconThemeData(color: colorScheme.primary),
        elevation: 0,
      ),
      backgroundColor: colorScheme.background,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categoryTitles.length,
        itemBuilder: (context, index) {
          final category = categoryTitles[index];
          return Card(
            color: colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              title: Text(
                category,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: colorScheme.primary),
              onTap: () {
                final faqs = faqCategories[category]!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FaqCategoryScreen(
                      categoryName: category,
                      faqItems: faqs,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FaqCategoryScreen extends StatelessWidget {
  final String categoryName;
  final List<_FaqItem> faqItems;

  const _FaqCategoryScreen(
      {required this.categoryName, required this.faqItems, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: colorScheme.background,
        iconTheme: IconThemeData(color: colorScheme.primary),
        elevation: 0,
      ),
      backgroundColor: colorScheme.background,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqItems.length,
        itemBuilder: (context, index) {
          final item = faqItems[index];
          return Card(
            color: colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              title: Text(
                item.question,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: colorScheme.primary),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FaqDetailScreen(faqItem: item)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}

class FaqDetailScreen extends StatelessWidget {
  final _FaqItem faqItem;

  const FaqDetailScreen({required this.faqItem, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ Detail'),
        backgroundColor: colorScheme.background,
        iconTheme: IconThemeData(color: colorScheme.primary),
        elevation: 0,
      ),
      backgroundColor: colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              faqItem.question,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              faqItem.answer,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
