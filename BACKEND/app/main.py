from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from BACKEND.app.api.router import api_router
from BACKEND.app.core.config import settings
from BACKEND.app.core.exceptions import register_exception_handlers

TAGS_METADATA = [
    {"name": "health", "description": "Service liveness and version information."},
    {"name": "trips", "description": "Create, read, update and delete trips."},
    {
        "name": "kyc",
        "description": "One-shot driver KYC verification (KTP/SIM + selfie). "
        "Images are processed in memory and never persisted.",
    },
]


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.project_name,
        description=settings.description,
        version=settings.version,
        openapi_tags=TAGS_METADATA,
        openapi_url=f"{settings.api_v1_prefix}/openapi.json",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_exception_handlers(app)
    app.include_router(api_router, prefix=settings.api_v1_prefix)
    return app


app = create_app()
