import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/themes/app_themes.dart';

class ThemeSwitchTile extends StatelessWidget {
  const ThemeSwitchTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppThemes.themeNotifier,
      builder: (_, ThemeMode themeMode, __) {
        return ListTile(
          title: const Text('Theme'),
          subtitle: Text(_getThemeModeName(themeMode)),
          leading: Icon(
            themeMode == ThemeMode.system
                ? Icons.brightness_auto
                : themeMode == ThemeMode.light
                ? Icons.brightness_5
                : Icons.brightness_3,
          ),
          onTap: () => _showThemeDialog(context, themeMode),
        );
      },
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemeDialog(BuildContext context, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeOption(context, ThemeMode.system, currentMode),
                _buildThemeOption(context, ThemeMode.light, currentMode),
                _buildThemeOption(context, ThemeMode.dark, currentMode),
              ],
            ),
          ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeMode mode,
    ThemeMode currentMode,
  ) {
    return RadioListTile<ThemeMode>(
      title: Text(_getThemeModeName(mode)),
      value: mode,
      groupValue: currentMode,
      onChanged: (ThemeMode? value) {
        if (value != null) {
          AppThemes.setThemeMode(value);
          Navigator.pop(context);
        }
      },
    );
  }
}
