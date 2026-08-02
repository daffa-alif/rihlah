from fastapi import APIRouter

from BACKEND.app.core.config import settings
from BACKEND.app.schemas.common import HealthResponse

router = APIRouter(tags=["health"])


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Liveness probe",
    description="Returns service status, version and active environment.",
)
async def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        version=settings.version,
        environment=settings.environment,
    )
