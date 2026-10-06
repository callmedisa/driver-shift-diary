import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'models.dart';
import 'widgets.dart';

class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.api, this.today});

  final DiaryApi api;

  /// Injectable for tests; defaults to the device's current date.
  final DateTime? today;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  DateTime? _date;
  DayReport? _report;
  String? _error;
  bool _loading = true;

  /// Incremented on every load. A response is shown only if no newer load has
  /// started, so quickly tapping through days never shows a stale day.
  int _requestId = 0;

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _openLatestDay();
  }

  Future<void> _openLatestDay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final days = await widget.api.days();
      await _load(days.isNotEmpty ? days.first : _today);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _load(DateTime date) async {
    final requestId = ++_requestId;
    setState(() {
      _date = date;
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.api.day(date);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _shift(int days) {
    final d = _date ?? _today;
    // Calendar arithmetic, not Duration(days: 1): stays correct across DST in other zones.
    _load(DateTime(d.year, d.month, d.day + days));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? _today,
      firstDate: DateTime(2020),
      lastDate: _today.add(const Duration(days: 365)),
    );
    if (picked != null) _load(picked);
  }

  Future<void> _retry() => _date == null ? _openLatestDay() : _load(_date!);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Дневник смен')),
      body: Column(
        children: [
          _DayPicker(
            date: _date,
            onPrevious: _date == null ? null : () => _shift(-1),
            onNext: _date == null ? null : () => _shift(1),
            onPick: _pickDate,
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _retry, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    final report = _report;
    if (report == null || (_loading && report.date != _date)) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _load(report.date),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SummaryCard(summary: report.summary),
          const SizedBox(height: 8),
          if (report.trips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('В этот день поездок не было', textAlign: TextAlign.center),
            )
          else
            Card(
              child: Column(children: [for (final t in report.trips) TripTile(trip: t)]),
            ),
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime? date;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Предыдущий день',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              onPressed: onPick,
              child: Text(
                date == null ? '…' : displayDate(date!),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Следующий день',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
