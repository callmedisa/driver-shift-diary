import json
from concurrent.futures import ThreadPoolExecutor

import pytest

from app.main import import_trips
from app.models import Trip
from app.repository import TripOverlap

from .conftest import trip

DAY = "/api/days/2026-10-01"


def day(client, path=DAY) -> dict:
    response = client.get(path)
    assert response.status_code == 200
    return response.json()


# --- day view ------------------------------------------------------------------

def test_day_returns_trips_and_summary(client):
    client.post("/api/trips", json=trip())
    client.post("/api/trips", json=trip(id="t2", start="2026-10-01T09:05:00+05:00",
                                        end="2026-10-01T09:20:00+05:00", amount=1500,
                                        payment="cash", commission=225))

    body = day(client)

    assert [t["id"] for t in body["trips"]] == ["t1", "t2"]
    assert body["summary"] == {
        "trips_count": 2, "revenue": 3900, "commission": 585, "net": 3315, "cash": 1500, "card": 2400,
    }


def test_trips_are_sorted_by_start_time(client):
    client.post("/api/trips", json=trip(id="late", start="2026-10-01T20:00:00+05:00",
                                        end="2026-10-01T20:30:00+05:00"))
    client.post("/api/trips", json=trip(id="early", start="2026-10-01T06:00:00+05:00",
                                        end="2026-10-01T06:30:00+05:00"))

    assert [t["id"] for t in day(client)["trips"]] == ["early", "late"]


def test_empty_day_has_zero_summary(client):
    body = day(client, "/api/days/2030-01-01")

    assert body["trips"] == []
    assert body["summary"]["trips_count"] == 0


def test_invalid_date_is_rejected(client):
    assert client.get("/api/days/2026-13-45").status_code == 422


# --- day boundaries and time zones ---------------------------------------------

def test_trip_crossing_midnight_belongs_to_the_day_it_started(client):
    client.post("/api/trips", json=trip(start="2026-10-01T23:45:00+05:00",
                                        end="2026-10-02T00:20:00+05:00"))

    assert day(client)["summary"]["trips_count"] == 1
    assert day(client, "/api/days/2026-10-02")["summary"]["trips_count"] == 0


def test_day_is_counted_in_local_time_not_utc(client):
    # 19:30 UTC on Sep 30 is 00:30 on Oct 1 in Kazakhstan (UTC+5).
    client.post("/api/trips", json=trip(start="2026-09-30T19:30:00Z", end="2026-09-30T19:50:00Z"))

    assert day(client)["summary"]["trips_count"] == 1
    assert day(client, "/api/days/2026-09-30")["summary"]["trips_count"] == 0


def test_old_trips_use_the_time_zone_in_force_at_that_time(client):
    # Almaty was UTC+6 until March 2024: 18:30 UTC on Jan 15, 2024 was 00:30 on Jan 16.
    client.post("/api/trips", json=trip(start="2024-01-15T18:30:00Z", end="2024-01-15T18:50:00Z"))

    stored = day(client, "/api/days/2024-01-16")["trips"]
    assert [t["start"] for t in stored] == ["2024-01-16T00:30:00+06:00"]


def test_times_are_returned_in_local_time(client):
    client.post("/api/trips", json=trip(start="2026-10-01T03:10:00Z", end="2026-10-01T03:32:00Z"))

    stored = day(client)["trips"][0]
    assert stored["start"] == "2026-10-01T08:10:00+05:00"
    assert stored["end"] == "2026-10-01T08:32:00+05:00"


def test_days_endpoint_lists_days_with_trips_newest_first(client):
    client.post("/api/trips", json=trip(id="a"))
    client.post("/api/trips", json=trip(id="b", start="2026-10-03T08:00:00+05:00",
                                        end="2026-10-03T08:30:00+05:00"))

    assert client.get("/api/days").json() == ["2026-10-03", "2026-10-01"]


# --- duplicates ----------------------------------------------------------------

def test_first_post_creates_the_trip(client):
    response = client.post("/api/trips", json=trip())

    assert response.status_code == 201
    assert response.json()["id"] == "t1"


def test_resending_the_same_trip_does_not_create_a_duplicate(client):
    first = client.post("/api/trips", json=trip())
    second = client.post("/api/trips", json=trip())

    assert first.status_code == 201
    assert second.status_code == 200
    assert second.json() == first.json()
    assert day(client)["summary"]["trips_count"] == 1


def test_same_trip_sent_with_another_utc_offset_is_still_a_duplicate(client):
    client.post("/api/trips", json=trip())
    again = client.post("/api/trips", json=trip(start="2026-10-01T03:10:00Z", end="2026-10-01T03:32:00Z"))

    assert again.status_code == 200
    assert day(client)["summary"]["trips_count"] == 1


def test_same_trip_with_fractional_seconds_is_still_a_duplicate(client):
    precise = trip(start="2026-10-01T08:10:00.123456+05:00")
    client.post("/api/trips", json=precise)

    assert client.post("/api/trips", json=precise).status_code == 200


def test_reusing_an_id_with_different_data_is_a_conflict(client):
    client.post("/api/trips", json=trip())
    response = client.post("/api/trips", json=trip(amount=9999))

    assert response.status_code == 409
    assert response.json()["detail"]["existing"]["amount"] == 2400
    assert day(client)["summary"]["revenue"] == 2400  # original is untouched


def test_same_trip_resent_under_a_new_id_is_rejected(client):
    client.post("/api/trips", json=trip())
    response = client.post("/api/trips", json=trip(id="t1-retry"))

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "overlap"
    assert day(client)["summary"]["trips_count"] == 1


def test_overlapping_trips_are_rejected(client):
    client.post("/api/trips", json=trip())  # 08:10-08:32
    response = client.post("/api/trips", json=trip(id="t2", start="2026-10-01T08:20:00+05:00",
                                                   end="2026-10-01T08:40:00+05:00"))

    assert response.status_code == 409
    assert response.json()["detail"]["existing"]["id"] == "t1"


def test_back_to_back_trips_are_allowed(client):
    client.post("/api/trips", json=trip())  # ends 08:32
    response = client.post("/api/trips", json=trip(id="t2", start="2026-10-01T08:32:00+05:00",
                                                   end="2026-10-01T08:50:00+05:00"))

    assert response.status_code == 201


def test_concurrent_overlapping_trips_create_exactly_one(repo):
    trips = [
        Trip(**trip(id=f"t{i}", start=f"2026-10-01T08:{10 + i:02d}:00+05:00",
                    end=f"2026-10-01T09:{10 + i:02d}:00+05:00"))
        for i in range(8)
    ]

    def add(t):
        try:
            return repo.add(t)[1]
        except TripOverlap:
            return False

    with ThreadPoolExecutor(max_workers=8) as pool:
        created = list(pool.map(add, trips))

    assert sum(created) == 1


def test_concurrent_duplicates_create_exactly_one_trip(repo):
    t = Trip(**trip())
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda _: repo.add(t), range(16)))

    assert sum(created for _, created in results) == 1
    assert len(repo.list_by_day(t.start.date())) == 1


# --- validation ----------------------------------------------------------------

@pytest.mark.parametrize(
    "overrides",
    [
        pytest.param({"amount": 0}, id="zero amount"),
        pytest.param({"amount": -100}, id="negative amount"),
        pytest.param({"amount": 2400.5}, id="fractional amount"),
        pytest.param({"amount": "2400"}, id="amount as string"),
        pytest.param({"end": "2026-10-01T08:10:00+05:00"}, id="end equals start"),
        pytest.param({"end": "2026-10-01T08:00:00+05:00"}, id="end before start"),
        pytest.param({"commission": -1}, id="negative commission"),
        pytest.param({"commission": 2401}, id="commission above amount"),
        pytest.param({"payment": "crypto"}, id="unknown payment"),
        pytest.param({"start": "2026-10-01T08:10:00"}, id="time without offset"),
        pytest.param({"id": ""}, id="empty id"),
        pytest.param({"tip": 100}, id="unknown field"),
        pytest.param({"id": "   "}, id="whitespace-only id"),
        pytest.param({"id": " t1"}, id="id with leading space"),
        pytest.param({"amount": 10**30, "commission": 0}, id="amount too large for SQLite"),
        pytest.param({"amount": 10_000_001}, id="amount above sanity limit"),
        pytest.param({"end": "2026-10-01T20:32:00+05:00"}, id="trip longer than 12 hours"),
        pytest.param({"start": "9999-12-31T22:00:00-05:00", "end": "9999-12-31T23:00:00-05:00"},
                     id="year 9999"),
        pytest.param({"start": "0001-01-01T00:10:00+05:00", "end": "0001-01-01T00:20:00+05:00"},
                     id="year 1"),
    ],
)
def test_invalid_trips_are_rejected_and_not_stored(client, overrides):
    response = client.post("/api/trips", json=trip(**overrides))

    assert response.status_code == 422
    assert day(client)["summary"]["trips_count"] == 0


def test_missing_field_is_rejected(client):
    body = trip()
    del body["payment"]

    assert client.post("/api/trips", json=body).status_code == 422


# --- seed import ---------------------------------------------------------------

def test_import_is_idempotent_and_skips_bad_records(repo, tmp_path):
    seed = tmp_path / "trips.json"
    seed.write_text(json.dumps([trip(), trip(id="bad", amount=0), "not a trip"]))

    import_trips(repo, seed)
    import_trips(repo, seed)  # e.g. after a restart

    assert [t.id for t in repo.list_by_day(Trip(**trip()).start.date())] == ["t1"]
