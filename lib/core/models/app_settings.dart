import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.readerDarkMode = false,
  });

  final ThemeMode themeMode;
  final bool readerDarkMode;

  AppSettings copyWith({ThemeMode? themeMode, bool? readerDarkMode}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      readerDarkMode: readerDarkMode ?? this.readerDarkMode,
    );
  }
}
