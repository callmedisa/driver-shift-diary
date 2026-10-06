// End-to-end check on a real device or emulator against the real API
// (started from data/trips.json). Run by CI; locally:
//   flutter test integration_test/app_test.dart --dart-define=API_BASE_URL=http://localhost:8000
// With screenshots (saved to mobile/screenshots/):
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart \
//     --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=SCREENSHOTS=true
import 'dart:io';

import 'package:driver_diary/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _nbsp = ' ';

/// Screenshots need `flutter drive` with test_driver/integration_test.dart,
/// so they are opt-in: plain `flutter test` runs skip them.
const _takeScreenshots = bool.fromEnvironment('SCREENSHOTS');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads days from the API and switches between them', (tester) async {
    app.main();

    // Opens on the newest day with trips: Oct 2, 3 trips, 5 695 ₸ take-home.
    await _waitFor(tester, find.text('5${_nbsp}695$_nbsp₸'));
    expect(find.text('Пт, 02.10.2026'), findsOneWidget);
    expect(find.text('6${_nbsp}700$_nbsp₸'), findsOneWidget); // revenue
    await _screenshot(binding, tester, '1-day-oct-02');

    // Previous day: Oct 1 includes the 23:45-00:20 trip that crosses midnight.
    await tester.tap(find.byTooltip('Предыдущий день'));
    await _waitFor(tester, find.text('11${_nbsp}900$_nbsp₸'));
    expect(find.text('Чт, 01.10.2026'), findsOneWidget);
    expect(find.text('14${_nbsp}000$_nbsp₸'), findsOneWidget);
    await _screenshot(binding, tester, '2-day-oct-01');

    // A day without trips.
    await tester.tap(find.byTooltip('Следующий день'));
    await _waitFor(tester, find.text('Пт, 02.10.2026'));
    await tester.tap(find.byTooltip('Следующий день'));
    await _waitFor(tester, find.text('В этот день поездок не было'));
    await _screenshot(binding, tester, '3-day-empty');

    // The Russian date picker opens.
    await tester.tap(find.text('Сб, 03.10.2026'));
    await _waitFor(tester, find.text('Выберите дату'));
    await _screenshot(binding, tester, '4-date-picker');
  });
}

/// Real network calls do not finish inside a single pump, so poll for the result.
Future<void> _waitFor(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out after $timeout waiting for $finder');
}

bool _surfaceConverted = false;

Future<void> _screenshot(IntegrationTestWidgetsFlutterBinding binding, WidgetTester tester, String name) async {
  if (!_takeScreenshots) return;
  if (Platform.isAndroid && !_surfaceConverted) {
    // Android needs the Flutter surface converted to an image once before screenshots.
    await binding.convertFlutterSurfaceToImage();
    _surfaceConverted = true;
  }
  await tester.pump(const Duration(milliseconds: 500));
  await binding.takeScreenshot(name);
}
