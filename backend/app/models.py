from datetime import UTC, date, datetime, timedelta
from enum import Enum

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator

# Sanity limits. They also keep values inside what SQLite INTEGER and datetime
# arithmetic can handle: without them 10**30 tenge or year 9999 caused a 500.
MAX_AMOUNT = 10_000_000  # tenge per trip
MAX_TRIP_DURATION = timedelta(hours=12)
EARLIEST = datetime(2000, 1, 1, tzinfo=UTC)
LATEST = datetime(2100, 1, 1, tzinfo=UTC)


class Payment(str, Enum):
    cash = "cash"
    card = "card"


class Trip(BaseModel):
    """A single trip. Money is stored in whole tenge to avoid float rounding."""

    model_config = ConfigDict(extra="forbid")

    # No leading/trailing or whitespace-only ids: "t1 " and "t1" must not be two trips.
    id: str = Field(min_length=1, max_length=64, pattern=r"^\S(.*\S)?$", strict=True)
    # AwareDatetime rejects timestamps without an offset: "08:10" is ambiguous
    # unless we know which time zone it is in.
    start: AwareDatetime
    end: AwareDatetime
    amount: int = Field(gt=0, le=MAX_AMOUNT, strict=True)
    payment: Payment
    commission: int = Field(ge=0, strict=True)

    @model_validator(mode="after")
    def check_consistency(self) -> "Trip":
        for moment in (self.start, self.end):
            if not EARLIEST <= moment < LATEST:
                raise ValueError("time must be between 2000 and 2100")
        if self.end <= self.start:
            raise ValueError("end must be later than start")
        if self.end - self.start > MAX_TRIP_DURATION:
            raise ValueError("trip cannot be longer than 12 hours")
        if self.commission > self.amount:
            raise ValueError("commission cannot exceed amount")
        return self

    def same_as(self, other: "Trip") -> bool:
        """Equal payloads, comparing instants rather than their textual offsets."""
        return (
            self.id == other.id
            and self.start == other.start
            and self.end == other.end
            and self.amount == other.amount
            and self.payment == other.payment
            and self.commission == other.commission
        )


class Summary(BaseModel):
    trips_count: int
    revenue: int
    commission: int
    net: int  # "на руки": revenue minus commission
    cash: int
    card: int


class Day(BaseModel):
    date: date
    summary: Summary
    trips: list[Trip]
