import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
      children: [
        Text(
          'Settings',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).setThemeMode(value);
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile(
                      value: ThemeMode.system,
                      title: Text('Use system theme'),
                      secondary: Icon(Icons.brightness_auto_rounded),
                    ),
                    RadioListTile(
                      value: ThemeMode.light,
                      title: Text('Light theme'),
                      secondary: Icon(Icons.light_mode_rounded),
                    ),
                    RadioListTile(
                      value: ThemeMode.dark,
                      title: Text('Dark theme'),
                      secondary: Icon(Icons.dark_mode_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.readerDarkMode,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggleReaderDarkMode(),
                title: const Text('Dark PDF reading'),
                subtitle: const Text('Invert bright PDF pages while reading'),
                secondary: const Icon(Icons.chrome_reader_mode_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Offline-first privacy'),
            subtitle: Text(
              'Documents and signatures stay on this device. OCR processing is performed locally.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Smart PDF Manager'),
            subtitle: Text('Version 1.0.0 • Android 8.0+'),
          ),
        ),
      ],
    );
  }
}
