import 'package:flutter/material.dart';

import 'format.dart';
import 'models.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row('Поездок', '${summary.tripsCount}'),
            _Row('Выручка', formatTenge(summary.revenue)),
            _Row('Комиссия', formatTenge(-summary.commission)),
            _Row('Наличные / карта', '${formatNumber(summary.cash)} / ${formatNumber(summary.card)}'),
            const Divider(height: 24),
            _Row(
              'На руки',
              formatTenge(summary.net),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.style});

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textStyle)),
          Text(value, style: textStyle),
        ],
      ),
    );
  }
}

class TripTile extends StatelessWidget {
  const TripTile({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        trip.payment == Payment.card ? Icons.credit_card : Icons.payments_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text('${wallClockTime(trip.start)}–${wallClockTime(trip.end)}'),
      subtitle: Text('${trip.payment.label} · комиссия ${formatTenge(trip.commission)}'),
      trailing: Text(formatTenge(trip.amount), style: theme.textTheme.titleMedium),
    );
  }
}
