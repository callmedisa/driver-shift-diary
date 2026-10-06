import 'package:flutter/material.dart';

import 'format.dart';
import 'models.dart';

abstract final class AppColors {
  static const brand = Color(0xFF0E7C5A);
  static const brandLight = Color(0xFF23B07E);
  static const background = Color(0xFFF2F5F3);
  static const text = Color(0xFF14201B);
  static const muted = Color(0xFF6B7A73);
  static const card = Color(0xFF3D6FE0);
  static const cash = Color(0xFFEFA234);
  static const commission = Color(0xFFC2502E);
}

Color paymentColor(Payment p) => p == Payment.card ? AppColors.card : AppColors.cash;

IconData paymentIcon(Payment p) =>
    p == Payment.card ? Icons.credit_card_rounded : Icons.payments_rounded;

/// Green header: app title, day switcher and the day's take-home amount.
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.date,
    required this.summary,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime? date;

  /// Null while the day is loading.
  final DaySummary? summary;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brand, AppColors.brandLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_taxi_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Дневник смен',
                    style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DateSwitcher(date: date, onPrevious: onPrevious, onNext: onNext, onPick: onPick),
              const SizedBox(height: 20),
              Text('На руки', style: text.titleSmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: 2),
              Text(
                summary == null ? '—' : formatTenge(summary!.net),
                style: text.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSwitcher extends StatelessWidget {
  const _DateSwitcher({
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Предыдущий день',
            onPressed: onPrevious,
            color: Colors.white,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      date == null ? '…' : displayDate(date!),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Следующий день',
            onPressed: onNext,
            color: Colors.white,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// White rounded surface used for every block below the header.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class StatTiles extends StatelessWidget {
  const StatTiles({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(Icons.route_rounded, 'Поездок', '${summary.tripsCount}', AppColors.brand)),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(Icons.trending_up_rounded, 'Выручка', formatTenge(summary.revenue), AppColors.card),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            Icons.percent_rounded,
            'Комиссия',
            formatTenge(-summary.commission),
            AppColors.commission,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.icon, this.label, this.value, this.color);

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.titleMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cash vs card as a two-colour bar with a legend.
class PaymentSplit extends StatelessWidget {
  const PaymentSplit({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cashShare = summary.revenue == 0 ? null : summary.cash / summary.revenue;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Наличные и карта',
            style: text.titleSmall?.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: cashShare ?? 0,
              minHeight: 10,
              color: AppColors.cash,
              backgroundColor: cashShare == null ? const Color(0xFFE3E8E5) : AppColors.card,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Legend(Payment.cash, 'Наличные', summary.cash)),
              Expanded(child: _Legend(Payment.card, 'Карта', summary.card)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.payment, this.label, this.amount);

  final Payment payment;
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: paymentColor(payment), shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: text.bodyMedium?.copyWith(color: AppColors.muted)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            formatTenge(amount),
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = paymentColor(trip.payment);
    final minutes = DateTime.parse(trip.end).difference(DateTime.parse(trip.start)).inMinutes;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallClockTime(trip.start),
                  style: text.titleMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
                ),
                Text(wallClockTime(trip.end), style: text.bodyMedium?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          Container(
            width: 3,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(paymentIcon(trip.payment), size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        trip.payment.label,
                        style: text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('$minutes мин', style: text.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatTenge(trip.amount),
                style: text.titleMedium?.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
              ),
              Text(
                formatTenge(-trip.commission),
                style: text.bodySmall?.copyWith(color: AppColors.commission),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.muted.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
