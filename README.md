# Smart PDF Manager

An offline-first Android PDF productivity suite built with Flutter 3.44 and
Dart 3.12. The minimum supported Android version is Android 8.0 (API 26).

## Features

- PDF reading, search, zoom, page jump, dark reading, and annotations
- Recent files, favorites, rename, delete, share, copy, move, and details
- Reusable drawn signatures with page, position, and size controls
- Text, image, scanned document, OCR text, and DOCX-to-PDF creation
- Merge, split, compress, password, watermark, and text-overlay tools
- Multi-page camera scanning with crop and reorder
- Offline ML Kit OCR
- Material 3 light/dark themes and responsive dashboard
- User-friendly interstitial monetization after successful PDF exports
- Debug-only dashboard banner for layout verification

## Run

```powershell
flutter pub get
flutter run
```

Validated commands:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

The verified debug APK is generated at:

`build/app/outputs/flutter-apk/app-debug.apk`

## Release Checklist

1. The production AdMob App ID is configured in
   `android/app/src/main/AndroidManifest.xml`.
2. The production interstitial unit is configured in
   `lib/core/services/ad_service.dart`. Debug builds automatically use
   Google's test unit.
3. Configure a private Android release keystore and replace the debug signing
   fallback in `android/app/build.gradle.kts`.
4. Confirm Syncfusion Community or commercial license eligibility.
5. Build an Android App Bundle with `flutter build appbundle --release`.
6. Test camera, storage access, OCR, password-protected files, and large PDFs
   on physical Android 8, 11, and current-version devices.

## Notes

- DOCX conversion is fully offline and retains text and paragraph structure.
  Complex Word layouts, charts, and embedded fonts cannot be reproduced
  exactly without a desktop rendering engine or server-side Office converter.
- PDF compression optimizes PDF streams. Already-compressed image-heavy PDFs
  may see a modest reduction unless their images are rasterized and resampled.
- Output files are stored in the app's external `Smart PDF Manager` directory.
- Interstitials are shown only after successful output creation: first after
  two completed tasks, then after at least three more tasks and a three-minute
  cooldown, with a maximum of two per app session.
- `android/gradle.properties` disables Kotlin incremental compilation because
  this Windows workspace is on `D:` while the Pub cache is on `C:`.
