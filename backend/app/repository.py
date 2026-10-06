import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import UTC, date, datetime, tzinfo
from pathlib import Path

from .models import Payment, Trip

SCHEMA = """
CREATE TABLE IF NOT EXISTS trips (
    id          TEXT PRIMARY KEY,
    start_utc   TEXT NOT NULL,
    end_utc     TEXT NOT NULL,
    local_date  TEXT NOT NULL,
    amount      INTEGER NOT NULL CHECK (amount > 0),
    payment     TEXT NOT NULL CHECK (payment IN ('cash', 'card')),
    commission  INTEGER NOT NULL CHECK (commission >= 0 AND commission <= amount),
    CHECK (end_utc > start_utc)
);
CREATE INDEX IF NOT EXISTS trips_local_date ON trips (local_date, start_utc);
"""


class TripConflict(Exception):
    """A trip with this id already exists with different data."""

    def __init__(self, existing: Trip):
        super().__init__(f"trip {existing.id!r} already exists with different data")
        self.existing = existing


class TripRepository:
    def __init__(self, path: Path | str, local_tz: tzinfo):
        self.path = str(path)
        self.local_tz = local_tz
        with self._connect() as conn:
            conn.executescript(SCHEMA)

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        try:
            with conn:  # commits on success, rolls back on error
                yield conn
        finally:
            conn.close()

    def add(self, trip: Trip) -> tuple[Trip, bool]:
        """Store a trip idempotently.

        Returns (trip, created). Re-sending the same trip returns the stored one
        with created=False; re-using an id with different data raises TripConflict.
        The INSERT ... ON CONFLICT DO NOTHING is atomic, so two concurrent
        requests with the same id cannot both create a row.
        """
        with self._connect() as conn:
            cur = conn.execute(
                """
                INSERT INTO trips (id, start_utc, end_utc, local_date, amount, payment, commission)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (id) DO NOTHING
                """,
                (
                    trip.id,
                    _utc_text(trip.start),
                    _utc_text(trip.end),
                    self.local_day(trip.start).isoformat(),
                    trip.amount,
                    trip.payment.value,
                    trip.commission,
                ),
            )
            if cur.rowcount == 1:
                return self._localize(trip), True
            row = conn.execute("SELECT * FROM trips WHERE id = ?", (trip.id,)).fetchone()

        existing = self._from_row(row)
        if existing.same_as(trip):
            return existing, False
        raise TripConflict(existing)

    def list_by_day(self, day: date) -> list[Trip]:
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT * FROM trips WHERE local_date = ? ORDER BY start_utc, id",
                (day.isoformat(),),
            ).fetchall()
        return [self._from_row(r) for r in rows]

    def days(self) -> list[date]:
        """Days that have at least one trip, newest first."""
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT DISTINCT local_date FROM trips ORDER BY local_date DESC"
            ).fetchall()
        return [date.fromisoformat(r["local_date"]) for r in rows]

    def local_day(self, moment: datetime) -> date:
        return moment.astimezone(self.local_tz).date()

    def _localize(self, trip: Trip) -> Trip:
        return trip.model_copy(
            update={
                "start": trip.start.astimezone(self.local_tz),
                "end": trip.end.astimezone(self.local_tz),
            }
        )

    def _from_row(self, row: sqlite3.Row) -> Trip:
        return Trip(
            id=row["id"],
            start=datetime.fromisoformat(row["start_utc"]).astimezone(self.local_tz),
            end=datetime.fromisoformat(row["end_utc"]).astimezone(self.local_tz),
            amount=row["amount"],
            payment=Payment(row["payment"]),
            commission=row["commission"],
        )


def _utc_text(moment: datetime) -> str:
    # Fixed-width UTC text sorts chronologically, so SQL ORDER BY works on it.
    # Microseconds are kept: dropping them made a re-sent trip look different
    # (false 409) and could make end == start in storage.
    return moment.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S.%f+00:00")
