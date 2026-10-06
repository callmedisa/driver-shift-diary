import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'day_screen.dart';

/// Override at build time: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
/// (10.0.2.2 is the host machine as seen from the Android emulator).
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

void main() {
  runApp(DriverDiaryApp(api: DiaryApi(apiBaseUrl)));
}

class DriverDiaryApp extends StatelessWidget {
  const DriverDiaryApp({super.key, required this.api});

  final DiaryApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Дневник смен',
      debugShowCheckedModeBanner: false,
      // Russian system widgets (date picker, tooltips) to match the rest of the UI.
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1E6B52), useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E6B52),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: DayScreen(api: api),
    );
  }
}
