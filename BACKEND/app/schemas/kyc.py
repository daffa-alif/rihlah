"""Pydantic schemas for driver KYC verification.

Nothing here is persisted: a request is decoded, scored and validated once,
then discarded (see app/services/kyc/). These models exist to make that
one-shot payload — both what the client must submit and what the server
returns — as explicit and cross-checkable as possible.
"""

from datetime import date, datetime
from enum import StrEnum

from pydantic import BaseModel, Field, field_validator


class DocumentType(StrEnum):
    KTP = "KTP"
    SIM = "SIM"


class VehicleType(StrEnum):
    MOTOR = "MOTOR"
    MOBIL = "MOBIL"


class SimClass(StrEnum):
    A = "A"
    A_UMUM = "A_UMUM"
    B1 = "B1"
    B1_UMUM = "B1_UMUM"
    B2 = "B2"
    B2_UMUM = "B2_UMUM"
    C = "C"
    C1 = "C1"
    C2 = "C2"
    D = "D"
    D1 = "D1"


# Vehicle categories each SIM class authorizes to drive (UU LLAJ 22/2009 §80).
MOTOR_SIM_CLASSES = {SimClass.C, SimClass.C1, SimClass.C2, SimClass.D, SimClass.D1}
MOBIL_SIM_CLASSES = {
    SimClass.A,
    SimClass.A_UMUM,
    SimClass.B1,
    SimClass.B1_UMUM,
    SimClass.B2,
    SimClass.B2_UMUM,
}

# Minimum legal age per SIM class (PP 42/1993 §14).
MIN_AGE_BY_SIM_CLASS: dict[SimClass, int] = {
    SimClass.A: 17,
    SimClass.A_UMUM: 20,
    SimClass.B1: 20,
    SimClass.B1_UMUM: 22,
    SimClass.B2: 21,
    SimClass.B2_UMUM: 23,
    SimClass.C: 17,
    SimClass.C1: 18,
    SimClass.C2: 19,
    SimClass.D: 17,
    SimClass.D1: 17,
}


class Gender(StrEnum):
    LAKI_LAKI = "LAKI_LAKI"
    PEREMPUAN = "PEREMPUAN"


class MaritalStatus(StrEnum):
    BELUM_KAWIN = "BELUM_KAWIN"
    KAWIN = "KAWIN"
    CERAI_HIDUP = "CERAI_HIDUP"
    CERAI_MATI = "CERAI_MATI"


class Religion(StrEnum):
    ISLAM = "ISLAM"
    KRISTEN = "KRISTEN"
    KATOLIK = "KATOLIK"
    HINDU = "HINDU"
    BUDDHA = "BUDDHA"
    KONGHUCU = "KONGHUCU"
    LAINNYA = "LAINNYA"


class KycStatus(StrEnum):
    VERIFIED = "VERIFIED"
    REJECTED = "REJECTED"


class DataSource(StrEnum):
    """Whether a field came from OCR of a live-captured photo or a driver claim."""

    OCR = "OCR"
    MANUAL = "MANUAL"


class Address(BaseModel):
    street: str = Field(min_length=1, max_length=200, examples=["Jl. Merdeka No. 17"])
    rt_rw: str | None = Field(default=None, examples=["003/005"])
    village: str = Field(
        min_length=1, max_length=100, description="Kelurahan/Desa", examples=["Cikini"]
    )
    district: str = Field(
        min_length=1, max_length=100, description="Kecamatan", examples=["Menteng"]
    )
    city: str = Field(
        min_length=1,
        max_length=100,
        description="Kota/Kabupaten",
        examples=["Jakarta Pusat"],
    )
    province: str | None = Field(default=None, examples=["DKI Jakarta"])


# --- Data extracted on-the-fly from the live-captured document photo -------


class KtpExtractedData(BaseModel):
    """Fields OCR'd from the KTP photo. Never derived from anything stored."""

    nik: str = Field(pattern=r"^\d{16}$", examples=["3173010101990001"])
    full_name: str = Field(min_length=1, max_length=100)
    place_of_birth: str = Field(min_length=1, max_length=100)
    date_of_birth: date
    gender: Gender | None = None
    address: Address | None = None
    religion: Religion | None = None
    marital_status: MaritalStatus | None = None
    occupation: str | None = Field(default=None, max_length=100)
    nationality: str = Field(default="WNI")
    valid_until: str = Field(
        default="SEUMUR HIDUP", description="KTP is usually lifetime-valid."
    )
    raw_ocr_text: str = Field(description="Unprocessed OCR text, for audit/debugging.")
    ocr_confidence: float = Field(ge=0, le=1)


class SimExtractedData(BaseModel):
    """Fields OCR'd from the SIM photo."""

    sim_number: str = Field(min_length=8, max_length=20)
    sim_class: SimClass
    full_name: str = Field(min_length=1, max_length=100)
    date_of_birth: date
    place_of_birth: str | None = Field(default=None, max_length=100)
    address: Address | None = None
    issued_date: date | None = None
    valid_until: date
    raw_ocr_text: str
    ocr_confidence: float = Field(ge=0, le=1)


class VehicleData(BaseModel):
    """Vehicle/STNK data — OCR'd from an STNK photo when provided, else the
    driver's claim, business-rule-checked either way."""

    plate_number: str = Field(examples=["B 1234 XYZ"])
    owner_name: str = Field(min_length=1, max_length=100)
    brand: str = Field(min_length=1, max_length=60, examples=["Honda"])
    model: str = Field(min_length=1, max_length=60, examples=["Vario 160"])
    year: int = Field(ge=1980, le=2100)
    color: str | None = None
    tax_valid_until: date | None = None
    source: DataSource
    raw_ocr_text: str | None = None
    ocr_confidence: float | None = Field(default=None, ge=0, le=1)

    @field_validator("plate_number")
    @classmethod
    def normalize_plate(cls, v: str) -> str:
        return " ".join(v.strip().upper().split())


# --- What the driver claims up front, before OCR runs ----------------------
#
# Identity (NIK/name/date of birth) is deliberately *not* claimed here
# anymore — it comes entirely from OCR on the document photo plus the
# Dukcapil confirmation (see app/services/kyc/dukcapil.py), so there is
# nothing for the driver to type and nothing for a bad actor to fake by
# typing something that doesn't match their photo. Only the vehicle (which
# OCR can't always fully cover, e.g. no STNK photo) and financial data are
# still driver-supplied.


class DriverClaimedVehicle(BaseModel):
    plate_number: str
    vehicle_type: VehicleType
    brand: str | None = None
    model: str | None = None
    year: int | None = Field(default=None, ge=1980, le=2100)


class FinancialData(BaseModel):
    """Optional payout details. Holder name must match the KTP name."""

    bank_name: str = Field(min_length=1, max_length=60)
    bank_account_number: str = Field(pattern=r"^\d{6,20}$")
    bank_account_holder_name: str = Field(min_length=1, max_length=100)
    skck_number: str | None = Field(default=None, max_length=40)
    skck_valid_until: date | None = None


class GeoLocation(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class DeviceMetadataInput(BaseModel):
    """Client-supplied device fingerprint. IP and User-Agent are read
    server-side from the request instead, since a client can't be trusted to
    self-report those honestly."""

    device_id: str = Field(min_length=8, max_length=200)
    location: GeoLocation


class DeviceMetadataResult(DeviceMetadataInput):
    ip_address: str
    user_agent: str
    within_service_area: bool


# --- The one JSON field the client sends alongside the photo uploads -------


class KycVerificationRequest(BaseModel):
    """The non-file part of the multipart submission (sent as a JSON string
    in the `payload` form field, alongside the photo uploads)."""

    document_type: DocumentType
    claimed_vehicle: DriverClaimedVehicle
    financial: FinancialData | None = None
    device: DeviceMetadataInput


# --- Dukcapil (civil registry) identity confirmation ------------------------


class DukcapilStatus(StrEnum):
    """Result of checking the OCR'd identity against Dukcapil.

    STUB responses can only ever be MATCHED or UNAVAILABLE — see
    app/services/kyc/dukcapil.py for why. MISMATCH/NOT_FOUND are modeled now
    so the response shape doesn't need to change once a real integration
    replaces the stub.
    """

    MATCHED = "MATCHED"
    NOT_FOUND = "NOT_FOUND"
    MISMATCH = "MISMATCH"
    UNAVAILABLE = "UNAVAILABLE"


class DukcapilConfirmationResult(BaseModel):
    """Outcome of confirming the OCR-extracted identity against Dukcapil.

    Nothing here is driver-claimed: `nik`/`full_name` are exactly what OCR
    read off the KTP, sent for confirmation rather than compared against a
    manual entry.
    """

    status: DukcapilStatus
    nik: str | None
    full_name: str | None
    checked_at: datetime
    source: str = Field(
        default="STUB",
        description=(
            "'STUB' means no real Dukcapil API call was made (see "
            "app/services/kyc/dukcapil.py); a real integration would set "
            "this to something like 'DUKCAPIL_API'."
        ),
    )
    notes: str | None = None


# --- Proof that biometric processing happened, without keeping the photos --


class LivenessBehaviorResult(BaseModel):
    """Multi-frame, behavior-based liveness signal (see
    app/services/kyc/vision.py's analyze_liveness_frames).

    Derived from an ordered burst of live-captured selfie frames (e.g.
    extracted client-side from a couple of seconds of video), not a single
    photo — a static photo or screen replay can't produce a genuine blink or
    natural head/face movement across frames.
    """

    frames_received: int = Field(description="Frames submitted in this request.")
    frames_with_face: int = Field(description="Of those, frames with a detected face.")
    blink_detected: bool = Field(
        description="An open->closed->open eye-state transition was observed."
    )
    motion_score: float = Field(
        ge=0, le=1, description="Normalized natural face movement across frames."
    )
    sharpness_score: float = Field(
        ge=0, le=1, description="Average single-frame sharpness proxy (see vision.py)."
    )
    liveness_confidence_score: float = Field(
        ge=0, le=1, description="Blend of blink/motion/sharpness signals."
    )
    liveness_passed: bool


class BiometricResult(BaseModel):
    id_face_detected: bool
    selfie_face_detected: bool
    face_match_score: float = Field(ge=0, le=1)
    face_match_passed: bool
    liveness: LivenessBehaviorResult
    verified_at: datetime = Field(examples=["2026-08-01T20:45:00Z"])


class CrossValidationCheck(BaseModel):
    """One field-level internal-consistency check — e.g. the birth date
    encoded in the NIK's own digits vs. the birth date printed elsewhere on
    the same KTP. Nothing here compares against a driver-typed claim
    anymore; both sides come from the document/registry."""

    field: str
    extracted_value: str | None
    claimed_value: str | None
    matched: bool


class KycVerificationResponse(BaseModel):
    request_id: str = Field(
        description="Correlation id for this single check; not a stored record id."
    )
    status: KycStatus
    document_type: DocumentType
    ktp: KtpExtractedData | None = None
    sim: SimExtractedData | None = None
    vehicle: VehicleData
    biometrics: BiometricResult
    dukcapil: DukcapilConfirmationResult
    device: DeviceMetadataResult
    financial: FinancialData | None = None
    cross_validation: list[CrossValidationCheck]
    rejection_reasons: list[str]
    processed_at: datetime
    image_retention_notice: str = Field(
        default=(
            "Uploaded photos were decoded in memory, processed once, and "
            "discarded. No image bytes were written to disk or persisted "
            "in any datastore."
        )
    )
