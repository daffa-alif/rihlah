from dataclasses import dataclass, field
from datetime import UTC, date, datetime


def _now() -> datetime:
    return datetime.now(UTC)


@dataclass
class Trip:
    """Domain model for a trip.

    Plain dataclass for now. When a database is added this becomes the ORM
    model (e.g. a SQLAlchemy declarative class) — the schemas and service
    layer keep the same shape.
    """

    id: str
    title: str
    destination: str
    start_date: date
    end_date: date
    notes: str | None = None
    created_at: datetime = field(default_factory=_now)
    updated_at: datetime = field(default_factory=_now)
