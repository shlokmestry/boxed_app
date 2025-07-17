import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemePickerSheet extends StatelessWidget {
  const ThemePickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.nights_stay, color: Colors.white70),
            title: const Text('Dark Mode', style: TextStyle(color: Colors.white)),
            trailing: themeProvider.themeMode == ThemeMode.dark
                ? const Icon(Icons.check, color: Colors.white)
                : null,
            onTap: () {
              themeProvider.setTheme(AppThemeMode.dark);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny, color: Colors.white70),
            title: const Text('Light Mode', style: TextStyle(color: Colors.white)),
            trailing: themeProvider.themeMode == ThemeMode.light
                ? const Icon(Icons.check, color: Colors.white)
                : null,
            onTap: () {
              themeProvider.setTheme(AppThemeMode.light);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
