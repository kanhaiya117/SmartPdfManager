import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/document_record.dart';
import '../services/ad_service.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences must be overridden.'),
);

final fileServiceProvider = Provider((ref) => FileService());
final pdfServiceProvider = Provider(
  (ref) => PdfService(ref.watch(fileServiceProvider)),
);
final interstitialAdServiceProvider = Provider((ref) {
  final service = InterstitialAdService()..preload();
  ref.onDispose(service.dispose);
  return service;
});

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _themeKey = 'theme_mode';
  static const _readerDarkKey = 'reader_dark_mode';

  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final storedTheme = _preferences.getString(_themeKey);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == storedTheme,
        orElse: () => ThemeMode.system,
      ),
      readerDarkMode: _preferences.getBool(_readerDarkKey) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _preferences.setString(_themeKey, mode.name);
  }

  Future<void> toggleReaderDarkMode() async {
    state = state.copyWith(readerDarkMode: !state.readerDarkMode);
    await _preferences.setBool(_readerDarkKey, state.readerDarkMode);
  }
}

final documentsProvider =
    NotifierProvider<DocumentsNotifier, List<DocumentRecord>>(
      DocumentsNotifier.new,
    );

class DocumentsNotifier extends Notifier<List<DocumentRecord>> {
  static const _storageKey = 'recent_documents_v1';

  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  List<DocumentRecord> build() {
    return DocumentRecord.decodeList(_preferences.getString(_storageKey));
  }

  Future<void> add(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final existing = state.where((item) => item.path == path).firstOrNull;
    final record = DocumentRecord(
      path: path,
      name: file.uri.pathSegments.last,
      openedAt: DateTime.now(),
      isFavorite: existing?.isFavorite ?? false,
      size: await file.length(),
    );
    state = [
      record,
      ...state.where((item) => item.path != path),
    ].take(50).toList();
    await _save();
  }

  Future<void> toggleFavorite(String path) async {
    state = [
      for (final item in state)
        if (item.path == path)
          item.copyWith(isFavorite: !item.isFavorite)
        else
          item,
    ];
    await _save();
  }

  Future<void> remove(String path) async {
    state = state.where((item) => item.path != path).toList();
    await _save();
  }

  Future<void> replacePath(String oldPath, String newPath) async {
    final file = File(newPath);
    state = [
      for (final item in state)
        if (item.path == oldPath)
          item.copyWith(
            path: newPath,
            name: file.uri.pathSegments.last,
            size: await file.length(),
          )
        else
          item,
    ];
    await _save();
  }

  Future<void> _save() =>
      _preferences.setString(_storageKey, DocumentRecord.encodeList(state));
}
