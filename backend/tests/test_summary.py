from app.models import Trip, Summary
from app.summary import summarize

from .conftest import trip


def test_summary_matches_the_example_from_the_task():
    trips = [
        Trip(**trip()),
        Trip(**trip(id="t2", start="2026-10-01T09:05:00+05:00", end="2026-10-01T09:20:00+05:00",
                    amount=1500, payment="cash", commission=225)),
    ]

    assert summarize(trips) == Summary(
        trips_count=2, revenue=3900, commission=585, net=3315, cash=1500, card=2400
    )


def test_summary_of_an_empty_day_is_all_zeros():
    assert summarize([]) == Summary(trips_count=0, revenue=0, commission=0, net=0, cash=0, card=0)


def test_cash_and_card_always_add_up_to_revenue():
    trips = [
        Trip(**trip(id=f"t{i}", amount=1000 + i, payment="cash" if i % 3 else "card", commission=i))
        for i in range(10)
    ]
    s = summarize(trips)

    assert s.cash + s.card == s.revenue
    assert s.net == s.revenue - s.commission
