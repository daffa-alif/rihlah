import uuid
from datetime import UTC, datetime

from BACKEND.app.core.exceptions import AppError, NotFoundError
from BACKEND.app.models.trip import Trip
from BACKEND.app.schemas.trip import TripCreate, TripUpdate


class TripService:
    """In-memory trip store.

    This is a placeholder so the API is runnable end to end. Swap the dict for
    a real repository/session when the database lands — the method signatures
    are what the routes depend on.
    """

    def __init__(self) -> None:
        self._trips: dict[str, Trip] = {}

    def list(
        self,
        *,
        limit: int = 20,
        offset: int = 0,
        destination: str | None = None,
    ) -> tuple[list[Trip], int]:
        trips = list(self._trips.values())
        if destination:
            needle = destination.casefold()
            trips = [t for t in trips if needle in t.destination.casefold()]
        trips.sort(key=lambda t: t.start_date)
        return trips[offset : offset + limit], len(trips)

    def get(self, trip_id: str) -> Trip:
        trip = self._trips.get(trip_id)
        if trip is None:
            raise NotFoundError(f"Trip '{trip_id}' was not found.")
        return trip

    def create(self, payload: TripCreate) -> Trip:
        trip = Trip(id=str(uuid.uuid4()), **payload.model_dump())
        self._trips[trip.id] = trip
        return trip

    def update(self, trip_id: str, payload: TripUpdate) -> Trip:
        trip = self.get(trip_id)
        changes = payload.model_dump(exclude_unset=True)

        start = changes.get("start_date", trip.start_date)
        end = changes.get("end_date", trip.end_date)
        if end < start:
            raise AppError("end_date must be on or after start_date")

        for key, value in changes.items():
            setattr(trip, key, value)
        trip.updated_at = datetime.now(UTC)
        return trip

    def delete(self, trip_id: str) -> None:
        self.get(trip_id)
        del self._trips[trip_id]

    def clear(self) -> None:
        """Reset the store — used by tests."""
        self._trips.clear()


trip_service = TripService()
