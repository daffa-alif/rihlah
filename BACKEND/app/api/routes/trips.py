from fastapi import APIRouter, Query, status

from BACKEND.app.api.deps import LimitDep, OffsetDep, TripServiceDep
from BACKEND.app.schemas.common import ErrorResponse, Page
from BACKEND.app.schemas.trip import TripCreate, TripRead, TripUpdate

router = APIRouter(
    prefix="/trips",
    tags=["trips"],
    responses={422: {"model": ErrorResponse, "description": "Validation error"}},
)

NOT_FOUND = {404: {"model": ErrorResponse, "description": "Trip not found"}}


@router.get(
    "",
    response_model=Page[TripRead],
    summary="List trips",
    description="Paginated list of trips, optionally filtered by destination.",
)
async def list_trips(
    service: TripServiceDep,
    limit: LimitDep = 20,
    offset: OffsetDep = 0,
    destination: str | None = Query(
        default=None, description="Case-insensitive substring match on destination."
    ),
) -> Page[TripRead]:
    trips, total = service.list(limit=limit, offset=offset, destination=destination)
    return Page[TripRead](
        items=[TripRead.model_validate(t) for t in trips],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.post(
    "",
    response_model=TripRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a trip",
)
async def create_trip(payload: TripCreate, service: TripServiceDep) -> TripRead:
    return TripRead.model_validate(service.create(payload))


@router.get(
    "/{trip_id}",
    response_model=TripRead,
    responses=NOT_FOUND,
    summary="Get a trip by id",
)
async def get_trip(trip_id: str, service: TripServiceDep) -> TripRead:
    return TripRead.model_validate(service.get(trip_id))


@router.patch(
    "/{trip_id}",
    response_model=TripRead,
    responses=NOT_FOUND,
    summary="Partially update a trip",
)
async def update_trip(
    trip_id: str, payload: TripUpdate, service: TripServiceDep
) -> TripRead:
    return TripRead.model_validate(service.update(trip_id, payload))


@router.delete(
    "/{trip_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=NOT_FOUND,
    summary="Delete a trip",
)
async def delete_trip(trip_id: str, service: TripServiceDep) -> None:
    service.delete(trip_id)
