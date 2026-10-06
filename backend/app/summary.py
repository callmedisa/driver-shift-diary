from collections.abc import Iterable

from .models import Payment, Summary, Trip


def summarize(trips: Iterable[Trip]) -> Summary:
    trips = list(trips)
    revenue = sum(t.amount for t in trips)
    commission = sum(t.commission for t in trips)
    return Summary(
        trips_count=len(trips),
        revenue=revenue,
        commission=commission,
        net=revenue - commission,
        cash=sum(t.amount for t in trips if t.payment == Payment.cash),
        card=sum(t.amount for t in trips if t.payment == Payment.card),
    )
