import 'package:driver_diary/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups thousands with non-breaking spaces', () {
    expect(formatNumber(0), '0');
    expect(formatNumber(585), '585');
    expect(formatNumber(2400), '2 400');
    expect(formatNumber(1234567), '1 234 567');
  });

  test('formats tenge, including negative amounts', () {
    expect(formatTenge(3315), '3 315 ₸');
    expect(formatTenge(-585), '−585 ₸');
  });

  test('takes wall-clock time from the server timestamp, not the phone zone', () {
    expect(wallClockTime('2026-10-01T08:10:00+05:00'), '08:10');
    expect(wallClockTime('2026-10-01T23:45:00.123+05:00'), '23:45');
    expect(() => wallClockTime('08:10'), throwsFormatException);
  });

  test('formats dates for the API and for display', () {
    final d = DateTime(2026, 10, 1);
    expect(apiDate(d), '2026-10-01');
    expect(displayDate(d), 'Чт, 01.10.2026');
  });
}
