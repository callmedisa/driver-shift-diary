from datetime import date
from enum import Enum

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator


class Payment(str, Enum):
    cash = "cash"
    card = "card"


class Trip(BaseModel):
    """A single trip. Money is stored in whole tenge to avoid float rounding."""

    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=1, max_length=64, strict=True)
    # AwareDatetime rejects timestamps without an offset: "08:10" is ambiguous
    # unless we know which time zone it is in.
    start: AwareDatetime
    end: AwareDatetime
    amount: int = Field(gt=0, strict=True)
    payment: Payment
    commission: int = Field(ge=0, strict=True)

    @model_validator(mode="after")
    def check_consistency(self) -> "Trip":
        if self.end <= self.start:
            raise ValueError("end must be later than start")
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
