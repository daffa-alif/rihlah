from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator


class TripBase(BaseModel):
    title: str = Field(min_length=1, max_length=120, examples=["Weekend in Bandung"])
    destination: str = Field(
        min_length=1, max_length=120, examples=["Bandung, Indonesia"]
    )
    start_date: date = Field(examples=["2026-09-12"])
    end_date: date = Field(examples=["2026-09-14"])
    notes: str | None = Field(default=None, max_length=2000)

    @model_validator(mode="after")
    def check_date_order(self) -> "TripBase":
        if self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        return self


class TripCreate(TripBase):
    pass


class TripUpdate(BaseModel):
    """All fields optional — only what is sent gets changed."""

    title: str | None = Field(default=None, min_length=1, max_length=120)
    destination: str | None = Field(default=None, min_length=1, max_length=120)
    start_date: date | None = None
    end_date: date | None = None
    notes: str | None = Field(default=None, max_length=2000)


class TripRead(TripBase):
    model_config = ConfigDict(from_attributes=True)

    id: str = Field(examples=["3f1a7c9e-2b64-4d18-9d0a-6f2c1b5e8a11"])
    created_at: datetime
    updated_at: datetime
