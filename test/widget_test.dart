import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_pdf_manager/app.dart';
import 'package:smart_pdf_manager/core/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('dashboard renders core tools', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const SmartPdfManagerApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Smart PDF Manager'), findsOneWidget);
    expect(find.text('PDF Reader'), findsOneWidget);
    expect(find.text('Scan Document'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
  });
}
