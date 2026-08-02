"""Pure business-rule functions for KYC cross-validation.

Deliberately dependency-free (no cv2/pytesseract imports) so these rules can
be unit tested directly, without a real photo or a Tesseract install.
"""

import difflib
import re
from datetime import date

from BACKEND.app.core.config import settings
from BACKEND.app.schemas.kyc import (
    MIN_AGE_BY_SIM_CLASS,
    MOBIL_SIM_CLASSES,
    MOTOR_SIM_CLASSES,
    SimClass,
    VehicleType,
)

_PLATE_PATTERN = re.compile(r"^[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3}$")


def normalize_name(name: str) -> str:
    return " ".join(name.strip().upper().split())


def names_match(a: str, b: str, *, threshold: float | None = None) -> bool:
    threshold = settings.kyc_name_match_threshold if threshold is None else threshold
    ratio = difflib.SequenceMatcher(None, normalize_name(a), normalize_name(b)).ratio()
    return ratio >= threshold


def calculate_age(dob: date, *, on: date | None = None) -> int:
    on = on or date.today()
    return on.year - dob.year - ((on.month, on.day) < (dob.month, dob.day))


def parse_nik(nik: str) -> tuple[date | None, str | None]:
    """Decode the birth date + gender encoded in NIK digits 7-12 (DDMMYY,
    with +40 added to the day for female holders) — a real structural rule
    of the Indonesian NIK, not a heuristic."""
    if len(nik) != 16 or not nik.isdigit():
        return None, None

    dd, mm, yy = int(nik[6:8]), int(nik[8:10]), int(nik[10:12])
    gender = "PEREMPUAN" if dd > 40 else "LAKI_LAKI"
    if dd > 40:
        dd -= 40

    current_yy = date.today().year % 100
    century = 2000 if yy <= current_yy else 1900
    try:
        return date(century + yy, mm, dd), gender
    except ValueError:
        return None, None


def normalize_plate(plate: str) -> str:
    return " ".join(plate.strip().upper().split())


def is_valid_plate_format(plate: str) -> bool:
    return bool(_PLATE_PATTERN.match(normalize_plate(plate)))


def sim_expiry_status(valid_until: date, *, on: date | None = None) -> tuple[bool, int]:
    """Returns (is_acceptable, days_remaining); unacceptable if expired or
    inside the renewal warning window."""
    on = on or date.today()
    days_remaining = (valid_until - on).days
    return days_remaining >= settings.kyc_sim_expiry_warning_days, days_remaining


def sim_class_matches_vehicle(sim_class: SimClass, vehicle_type: VehicleType) -> bool:
    if vehicle_type == VehicleType.MOTOR:
        return sim_class in MOTOR_SIM_CLASSES
    return sim_class in MOBIL_SIM_CLASSES


def min_age_for_sim_class(sim_class: SimClass) -> int:
    return MIN_AGE_BY_SIM_CLASS[sim_class]


def vehicle_age_acceptable(year: int, *, on: date | None = None) -> bool:
    on = on or date.today()
    return (on.year - year) <= settings.kyc_max_vehicle_age_years


def within_service_area(latitude: float, longitude: float) -> bool:
    return (
        settings.kyc_service_area_south <= latitude <= settings.kyc_service_area_north
        and settings.kyc_service_area_west <= longitude <= settings.kyc_service_area_east
    )
