import 'package:flutter/material.dart';

import 'api.dart';
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
    // Same range the server accepts. The current day is clamped into it:
    // showDatePicker throws if initialDate is outside [firstDate, lastDate].
    final first = DateTime(2000);
    final last = DateTime(2099, 12, 31);
    final current = _date ?? _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first) ? first : (current.isAfter(last) ? last : current),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) _load(picked);
  }

  Future<void> _retry() => _date == null ? _openLatestDay() : _load(_date!);

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final current = report != null && report.date == _date ? report : null;
    return Scaffold(
      body: Column(
        children: [
          DayHeader(
            date: _date,
            summary: current?.summary,
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
        child: MessageView(
          icon: Icons.cloud_off_rounded,
          message: _error!,
          action: FilledButton(onPressed: _retry, child: const Text('Повторить')),
        ),
      );
    }
    final report = _report;
    if (report == null || (_loading && report.date != _date)) {
      return const Center(child: CircularProgressIndicator());
    }
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: () => _load(report.date),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          StatTiles(summary: report.summary),
          const SizedBox(height: 12),
          PaymentSplit(summary: report.summary),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Поездки',
                style: text.titleMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text('${report.trips.length}', style: text.titleSmall?.copyWith(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          if (report.trips.isEmpty)
            const MessageView(icon: Icons.event_busy_rounded, message: 'В этот день поездок не было')
          else
            for (final t in report.trips)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: TripCard(trip: t)),
        ],
      ),
    );
  }
}
