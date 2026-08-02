from typing import Annotated

from fastapi import Depends, Query

from BACKEND.app.services.kyc.service import KycService, kyc_service
from BACKEND.app.services.trip_service import TripService, trip_service


def get_trip_service() -> TripService:
    """Single injection point for the trip store, so tests can override it."""
    return trip_service


def get_kyc_service() -> KycService:
    return kyc_service


TripServiceDep = Annotated[TripService, Depends(get_trip_service)]
KycServiceDep = Annotated[KycService, Depends(get_kyc_service)]
LimitDep = Annotated[int, Query(ge=1, le=100, description="Max records to return.")]
OffsetDep = Annotated[int, Query(ge=0, description="Records to skip.")]
