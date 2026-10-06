import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'format.dart';
import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DiaryApi {
  DiaryApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 10);

  /// Days that have trips, newest first.
  Future<List<DateTime>> days() async {
    final body = await _get('/api/days') as List<dynamic>;
    return [for (final d in body) DateTime.parse(d as String)];
  }

  Future<DayReport> day(DateTime date) async {
    final body = await _get('/api/days/${apiDate(date)}');
    return DayReport.fromJson(body as Map<String, dynamic>);
  }

  Future<Object?> _get(String path) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse('$baseUrl$path')).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('Сервер не отвечает. Попробуйте ещё раз.');
    } on http.ClientException {
      throw const ApiException('Нет связи с сервером.');
    }
    if (response.statusCode != 200) {
      throw ApiException('Ошибка сервера (${response.statusCode}).');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
