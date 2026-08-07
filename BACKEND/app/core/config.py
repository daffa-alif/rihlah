from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings, loaded from environment variables or a .env file."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    project_name: str = "Rihlah API"
    description: str = "Backend API for the Rihlah trip planning platform."
    version: str = "0.2.0"
    api_v1_prefix: str = "/api/v1"

    environment: str = "development"
    debug: bool = True

    # Comma-separated list in the environment, e.g. CORS_ORIGINS=http://localhost:3000
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:5173"]

    # --- KYC processing (app/services/kyc/) ---------------------------------
    # Path to tesseract.exe if it isn't on PATH (Windows default install location
    # is typically "C:\Program Files\Tesseract-OCR\tesseract.exe").
    kyc_tesseract_cmd: str | None = None
    kyc_ocr_languages: str = "ind+eng"

    kyc_max_upload_mb: int = 8
    kyc_allowed_content_types: list[str] = ["image/jpeg", "image/png", "image/webp"]

    kyc_min_driver_age: int = 17
    kyc_sim_expiry_warning_days: int = 30
    kyc_max_vehicle_age_years: int = 10
    kyc_name_match_threshold: float = 0.82
    kyc_face_match_threshold: float = 0.55
    kyc_liveness_threshold: float = 0.5

    # Service-area geofence (defaults to all of Indonesia); narrow via env for
    # a real deployment, e.g. Jabodetabek only.
    kyc_service_area_south: float = -11.0
    kyc_service_area_north: float = 6.0
    kyc_service_area_west: float = 95.0
    kyc_service_area_east: float = 141.0

    # --- Liveness (frame-by-frame, see app/services/kyc/vision.py) --------
    # The client (Flutter app) captures a short live burst/video of the
    # selfie and uploads it as an ordered set of frames; the backend never
    # decodes a video container itself, it just analyzes whatever frames it
    # receives. min/max bound how many frames one request may submit.
    kyc_min_liveness_frames: int = 5
    kyc_max_liveness_frames: int = 40
    # Require an actual open->closed->open blink transition across the
    # frames, not just a high blended score, before liveness can pass.
    kyc_require_blink: bool = True

    # --- Dukcapil identity confirmation (app/services/kyc/dukcapil.py) -----
    # No real Dukcapil (Indonesian civil registry) credential exists for this
    # project yet, so this always talks to the in-process stub regardless of
    # these being set. They exist so swapping in the real integration later
    # is a config change, not a code change.
    kyc_dukcapil_base_url: str | None = None
    kyc_dukcapil_api_key: str | None = None

    @property
    def kyc_max_upload_bytes(self) -> int:
        return self.kyc_max_upload_mb * 1024 * 1024


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance so the .env file is only parsed once."""
    return Settings()


settings = get_settings()
