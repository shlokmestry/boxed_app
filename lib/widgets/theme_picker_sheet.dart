import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/providers/theme_provider.dart'; // adjust path as needed

class ThemePickerSheet extends StatelessWidget {
  const ThemePickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentThemeMode = themeProvider.themeMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: currentThemeMode,
            title: Row(
              children: [
                Icon(Icons.light_mode, color: Colors.amber),
                const SizedBox(width: 12),
                const Text("Light Mode"),
              ],
            ),
            onChanged: (mode) {
              themeProvider.setThemeMode(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: currentThemeMode,
            title: Row(
              children: [
                Icon(Icons.dark_mode, color: Colors.deepPurple),
                const SizedBox(width: 12),
                const Text("Dark Mode"),
              ],
            ),
            onChanged: (mode) {
              themeProvider.setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: currentThemeMode,
            title: Row(
              children: [
                Icon(Icons.phone_android, color: Colors.blue),
                const SizedBox(width: 12),
                const Text("System Default"),
              ],
            ),
            onChanged: (mode) {
              themeProvider.setThemeMode(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
