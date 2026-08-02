from fastapi import APIRouter

from BACKEND.app.api.routes import health, kyc
from BACKEND.app.api.routes import trips

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(trips.router)
api_router.include_router(kyc.router)
