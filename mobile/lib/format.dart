const _nbsp = ' ';
const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// 12400 -> "12 400", with non-breaking spaces so a number never wraps.
String formatNumber(int value) {
  final digits = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '−' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(_nbsp);
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Whole tenge: 2400 -> "2 400 ₸".
String formatTenge(int value) => '${formatNumber(value)}$_nbsp₸';

/// "HH:mm" taken from an ISO timestamp as the server sent it.
///
/// The server returns times already converted to the drivers' time zone
/// (UTC+5), so we show the wall-clock part as is instead of converting to the
/// phone's zone: a driver travelling with a phone set to another zone should
/// still see the times the fleet sees.
String wallClockTime(String iso) {
  final match = RegExp(r'T(\d{2}:\d{2})').firstMatch(iso);
  if (match == null) throw FormatException('Not an ISO timestamp', iso);
  return match.group(1)!;
}

/// Date as used in the API path: 2026-10-01.
String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// Date as shown to the driver: "Ср, 01.10.2026".
String displayDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_two(d.day)}.${_two(d.month)}.${d.year}';

String _two(int n) => n.toString().padLeft(2, '0');
