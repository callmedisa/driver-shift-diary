import 'dart:async';
import 'dart:convert';

import 'package:driver_diary/api.dart';
import 'package:driver_diary/day_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _oct1 = {
  'date': '2026-10-01',
  'summary': {'trips_count': 2, 'revenue': 3900, 'commission': 585, 'net': 3315, 'cash': 1500, 'card': 2400},
  'trips': [
    {'id': 't1', 'start': '2026-10-01T08:10:00+05:00', 'end': '2026-10-01T08:32:00+05:00',
     'amount': 2400, 'payment': 'card', 'commission': 360},
    {'id': 't2', 'start': '2026-10-01T09:05:00+05:00', 'end': '2026-10-01T09:20:00+05:00',
     'amount': 1500, 'payment': 'cash', 'commission': 225},
  ],
};

Map<String, Object> _emptyDay(String date) => {
      'date': date,
      'summary': {'trips_count': 0, 'revenue': 0, 'commission': 0, 'net': 0, 'cash': 0, 'card': 0},
      'trips': <Object>[],
    };

http.Response _json(Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );

Widget _app(http.Client client) => MaterialApp(
      home: DayScreen(api: DiaryApi('http://test', client: client), today: DateTime(2026, 10, 5)),
    );

void main() {
  testWidgets('opens the latest day with trips and shows its summary', (tester) async {
    final client = MockClient((request) async => switch (request.url.path) {
          '/api/days' => _json(['2026-10-01']),
          '/api/days/2026-10-01' => _json(_oct1),
          _ => http.Response('not found', 404),
        });

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    expect(find.text('Чт, 01.10.2026'), findsOneWidget);
    expect(find.text('3 315 ₸'), findsOneWidget); // на руки
    expect(find.text('−585 ₸'), findsOneWidget); // комиссия
    expect(find.text('1 500 / 2 400'), findsOneWidget); // наличные / карта
    expect(find.text('08:10–08:32'), findsOneWidget);
  });

  testWidgets('switches to the next day', (tester) async {
    final client = MockClient((request) async => switch (request.url.path) {
          '/api/days' => _json(['2026-10-01']),
          '/api/days/2026-10-01' => _json(_oct1),
          '/api/days/2026-10-02' => _json(_emptyDay('2026-10-02')),
          _ => http.Response('not found', 404),
        });

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Следующий день'));
    await tester.pumpAndSettle();

    expect(find.text('Пт, 02.10.2026'), findsOneWidget);
    expect(find.text('В этот день поездок не было'), findsOneWidget);
  });

  testWidgets('a slow response for an old day never replaces the current day', (tester) async {
    final slowOct1 = Completer<http.Response>();
    final client = MockClient((request) async => switch (request.url.path) {
          '/api/days' => _json(['2026-10-01']),
          '/api/days/2026-10-01' => slowOct1.future,
          '/api/days/2026-10-02' => _json(_emptyDay('2026-10-02')),
          _ => http.Response('not found', 404),
        });

    await tester.pumpWidget(_app(client));
    await tester.pump(); // days list arrives, Oct 1 request is now pending
    await tester.pump();
    await tester.tap(find.byTooltip('Следующий день'));
    await tester.pumpAndSettle(); // Oct 2 loads
    slowOct1.complete(_json(_oct1)); // stale Oct 1 response arrives late
    await tester.pumpAndSettle();

    expect(find.text('Пт, 02.10.2026'), findsOneWidget);
    expect(find.text('В этот день поездок не было'), findsOneWidget);
    expect(find.text('08:10–08:32'), findsNothing);
  });

  testWidgets('shows an error with a retry button when the server is down', (tester) async {
    var attempts = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/days' && attempts++ == 0) {
        throw http.ClientException('connection refused');
      }
      return switch (request.url.path) {
        '/api/days' => _json(['2026-10-01']),
        '/api/days/2026-10-01' => _json(_oct1),
        _ => http.Response('not found', 404),
      };
    });

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    expect(find.text('Нет связи с сервером.'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Чт, 01.10.2026'), findsOneWidget);
  });
}
