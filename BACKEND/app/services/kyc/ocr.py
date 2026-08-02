"""Tesseract OCR wrapper + regex-based field parsers for KTP/SIM/STNK.

The parsers are a best-effort layout reader for the Indonesian document
formats, not a certified government integration (that would mean calling the
Dukcapil NIK-verification API, which is out of scope here — this project has
no such credential). When required fields can't be located in the OCR text,
we raise rather than fabricate a value, so a caller never receives KYC data
that wasn't actually read off the document.
"""

import re
from datetime import date

import cv2
import numpy as np
import pytesseract
from pytesseract import TesseractNotFoundError

from BACKEND.app.core.config import settings
from BACKEND.app.core.exceptions import ServiceUnavailableError, UnprocessableEntityError

if settings.kyc_tesseract_cmd:
    pytesseract.pytesseract.tesseract_cmd = settings.kyc_tesseract_cmd


def _preprocess(image: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = cv2.bilateralFilter(gray, 9, 75, 75)
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return thresh


def extract_text(image: np.ndarray, *, field_name: str) -> tuple[str, float]:
    """Run OCR once over an in-memory document image.

    Returns (raw_text, confidence in [0, 1]) where confidence is the mean of
    Tesseract's own per-word confidences — a real measurement, not a guess.
    """
    processed = _preprocess(image)
    try:
        text = pytesseract.image_to_string(processed, lang=settings.kyc_ocr_languages)
        data = pytesseract.image_to_data(
            processed,
            lang=settings.kyc_ocr_languages,
            output_type=pytesseract.Output.DICT,
        )
    except TesseractNotFoundError as exc:
        raise ServiceUnavailableError(
            "Tesseract OCR engine is not installed or not on PATH. Install it "
            "(https://github.com/UB-Mannheim/tesseract/wiki on Windows) and/or "
            "set KYC_TESSERACT_CMD to its executable path."
        ) from exc

    if not text.strip():
        raise UnprocessableEntityError(
            f"No text could be read from {field_name}. Ensure the photo is "
            "sharp, well-lit, and shows the full document."
        )

    confidences = [float(c) for c in data.get("conf", []) if c not in ("-1", -1)]
    confidence = (
        round((sum(confidences) / len(confidences)) / 100, 4) if confidences else 0.0
    )
    return text, confidence


def _search(pattern: str, text: str, *, flags: int = re.IGNORECASE) -> str | None:
    match = re.search(pattern, text, flags)
    return match.group(1).strip() if match else None


def _parse_date(raw: str | None) -> date | None:
    if not raw:
        return None
    for sep in ("-", "/"):
        parts = raw.split(sep)
        if len(parts) == 3:
            try:
                d, m, y = (int(p) for p in parts)
                return date(y, m, d)
            except ValueError:
                continue
    return None


def _require(value: str | None, *, field: str, source: str) -> str:
    if not value:
        raise UnprocessableEntityError(
            f"Could not extract '{field}' from {source}. Ensure the photo is "
            "clear, well-lit, and fully visible."
        )
    return value


# --- KTP ---------------------------------------------------------------

_NIK_RE = r"NIK\s*[:\-]?\s*(\d{16})"
_NAME_RE = r"Nama\s*[:\-]?\s*([A-Z' .]{2,60})"
_TTL_RE = (
    r"(?:Tempat/?Tgl(?:\.|\s)?Lahir|TTL)\s*[:\-]?\s*"
    r"([A-Za-z .]+)[,\s]+(\d{2}[-/]\d{2}[-/]\d{4})"
)
_GENDER_RE = r"Jenis\s*Kelamin\s*[:\-]?\s*(LAKI-LAKI|LAKI2|PEREMPUAN)"
_RELIGION_RE = r"Agama\s*[:\-]?\s*(ISLAM|KRISTEN|KATOLIK|HINDU|BUDDHA|KONGHUCU)"
_MARITAL_RE = r"Status\s*Perkawinan\s*[:\-]?\s*(BELUM KAWIN|KAWIN|CERAI HIDUP|CERAI MATI)"
_OCCUPATION_RE = r"Pekerjaan\s*[:\-]?\s*([A-Za-z /.]{2,60})"
_RT_RW_RE = r"RT\s*/?\s*RW\s*[:\-]?\s*(\d{1,3}\s*/\s*\d{1,3})"
_VILLAGE_RE = r"Kel(?:\.|/)?\s*Desa\s*[:\-]?\s*([A-Za-z .]{2,50})"
_DISTRICT_RE = r"Kecamatan\s*[:\-]?\s*([A-Za-z .]{2,50})"
_ADDRESS_RE = r"Alamat\s*[:\-]?\s*([A-Za-z0-9 .,/'-]{3,100})"

_GENDER_MAP = {"LAKI-LAKI": "LAKI_LAKI", "LAKI2": "LAKI_LAKI", "PEREMPUAN": "PEREMPUAN"}
_MARITAL_MAP = {
    "BELUM KAWIN": "BELUM_KAWIN",
    "KAWIN": "KAWIN",
    "CERAI HIDUP": "CERAI_HIDUP",
    "CERAI MATI": "CERAI_MATI",
}


def parse_ktp(raw_text: str, *, confidence: float) -> dict:
    nik = _require(_search(_NIK_RE, raw_text), field="nik", source="the KTP photo")
    full_name = _require(
        _search(_NAME_RE, raw_text), field="full_name", source="the KTP photo"
    )

    ttl_match = re.search(_TTL_RE, raw_text, re.IGNORECASE)
    if not ttl_match:
        raise UnprocessableEntityError(
            "Could not extract 'Tempat/Tgl Lahir' from the KTP photo. Ensure "
            "the photo is clear, well-lit, and fully visible."
        )
    place_of_birth = ttl_match.group(1).strip(" ,")
    date_of_birth = _parse_date(ttl_match.group(2))
    if date_of_birth is None:
        raise UnprocessableEntityError(
            "Could not parse date of birth from the KTP photo."
        )

    gender_raw = _search(_GENDER_RE, raw_text)
    religion_raw = _search(_RELIGION_RE, raw_text)
    marital_raw = _search(_MARITAL_RE, raw_text)
    street = _search(_ADDRESS_RE, raw_text)
    village = _search(_VILLAGE_RE, raw_text)
    district = _search(_DISTRICT_RE, raw_text)

    address = None
    if street and village and district:
        address = {
            "street": street,
            "rt_rw": _search(_RT_RW_RE, raw_text),
            "village": village,
            "district": district,
            "city": district,
        }

    return {
        "nik": nik,
        "full_name": full_name.strip(),
        "place_of_birth": place_of_birth,
        "date_of_birth": date_of_birth,
        "gender": _GENDER_MAP.get(gender_raw.upper()) if gender_raw else None,
        "address": address,
        "religion": religion_raw.upper() if religion_raw else None,
        "marital_status": _MARITAL_MAP.get(marital_raw.upper()) if marital_raw else None,
        "occupation": _search(_OCCUPATION_RE, raw_text),
        "raw_ocr_text": raw_text,
        "ocr_confidence": confidence,
    }


# --- SIM -----------------------------------------------------------------

_SIM_NUMBER_RE = r"(\d{12,16})"
_SIM_CLASS_RE = r"\bSIM\s*[:\-]?\s*(A UMUM|B1 UMUM|B2 UMUM|A|B1|B2|C1|C2|C|D1|D)\b"
_SIM_VALID_UNTIL_RE = (
    r"Berlaku\s*(?:S\.?D\.?|Sampai(?:\s*Dengan)?|Hingga)\s*[:\-]?\s*"
    r"(\d{2}[-/]\d{2}[-/]\d{4})"
)
_SIM_ISSUED_RE = r"Tgl\.?\s*Dikeluarkan\s*[:\-]?\s*(\d{2}[-/]\d{2}[-/]\d{4})"


def parse_sim(raw_text: str, *, confidence: float) -> dict:
    sim_number = _require(
        _search(_SIM_NUMBER_RE, raw_text), field="sim_number", source="the SIM photo"
    )
    sim_class_raw = _require(
        _search(_SIM_CLASS_RE, raw_text), field="sim_class", source="the SIM photo"
    )
    sim_class = sim_class_raw.upper().replace(" ", "_")

    full_name = _require(
        _search(_NAME_RE, raw_text), field="full_name", source="the SIM photo"
    )

    valid_until = _parse_date(_search(_SIM_VALID_UNTIL_RE, raw_text))
    if valid_until is None:
        raise UnprocessableEntityError(
            "Could not extract the SIM expiration date. Ensure the photo is "
            "clear, well-lit, and fully visible."
        )

    ttl_match = re.search(_TTL_RE, raw_text, re.IGNORECASE)
    place_of_birth = ttl_match.group(1).strip(" ,") if ttl_match else None
    date_of_birth = _parse_date(ttl_match.group(2)) if ttl_match else None
    if date_of_birth is None:
        raise UnprocessableEntityError(
            "Could not parse date of birth from the SIM photo."
        )

    return {
        "sim_number": sim_number,
        "sim_class": sim_class,
        "full_name": full_name.strip(),
        "date_of_birth": date_of_birth,
        "place_of_birth": place_of_birth,
        "address": None,
        "issued_date": _parse_date(_search(_SIM_ISSUED_RE, raw_text)),
        "valid_until": valid_until,
        "raw_ocr_text": raw_text,
        "ocr_confidence": confidence,
    }


# --- STNK ------------------------------------------------------------------

_PLATE_RE = (
    r"(?:No\.?\s*Pol(?:isi)?|Nomor\s*Polisi)\s*[:\-]?\s*"
    r"([A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3})"
)
_OWNER_RE = r"Nama\s*(?:Pemilik)?\s*[:\-]?\s*([A-Z' .]{2,60})"
_BRAND_MODEL_RE = r"Merek\s*/?\s*Type\s*[:\-]?\s*([A-Za-z0-9 /-]{2,60})"
_YEAR_RE = r"Tahun\s*[:\-]?\s*(\d{4})"
_COLOR_RE = r"Warna\s*[:\-]?\s*([A-Za-z ]{2,30})"
_TAX_VALID_RE = (
    r"(?:Berlaku\s*Sampai|Pajak\s*S\.?D\.?)\s*[:\-]?\s*(\d{2}[-/]\d{2}[-/]\d{4})"
)


def parse_stnk(raw_text: str, *, confidence: float) -> dict:
    plate_number = _require(
        _search(_PLATE_RE, raw_text), field="plate_number", source="the STNK photo"
    )
    owner_name = _require(
        _search(_OWNER_RE, raw_text), field="owner_name", source="the STNK photo"
    )
    brand_model = _require(
        _search(_BRAND_MODEL_RE, raw_text), field="brand/model", source="the STNK photo"
    )
    year_raw = _require(
        _search(_YEAR_RE, raw_text), field="year", source="the STNK photo"
    )

    if "/" in brand_model:
        brand, model = (p.strip() for p in brand_model.split("/", 1))
    else:
        pieces = brand_model.split(maxsplit=1)
        brand = pieces[0]
        model = pieces[1] if len(pieces) > 1 else pieces[0]

    return {
        "plate_number": plate_number,
        "owner_name": owner_name.strip(),
        "brand": brand,
        "model": model,
        "year": int(year_raw),
        "color": _search(_COLOR_RE, raw_text),
        "tax_valid_until": _parse_date(_search(_TAX_VALID_RE, raw_text)),
        "source": "OCR",
        "raw_ocr_text": raw_text,
        "ocr_confidence": confidence,
    }
