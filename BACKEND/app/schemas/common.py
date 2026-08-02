from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = Field(examples=["ok"])
    version: str = Field(examples=["0.1.0"])
    environment: str = Field(examples=["development"])


class ErrorDetail(BaseModel):
    code: str = Field(examples=["not_found"])
    message: str = Field(examples=["Trip 'abc' was not found."])
    details: object | None = None


class ErrorResponse(BaseModel):
    error: ErrorDetail


class Page[T](BaseModel):
    """Envelope for list endpoints."""

    items: list[T]
    total: int = Field(description="Total number of matching records.")
    limit: int
    offset: int
