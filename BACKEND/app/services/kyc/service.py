"""KYC verification orchestrator.

Ties together vision (face detect/match/liveness), ocr (document text
extraction) and validation (business rules) into a single, one-shot check.

Nothing is persisted anywhere in this module: uploaded photo bytes are read
into local variables, decoded to in-memory arrays, used for detection/OCR,
and then simply go out of scope when `verify()` returns — there is no
database, cache or filesystem write in this path.
"""

import uuid
from datetime import UTC, date, datetime

from BACKEND.app.core.config import settings
from BACKEND.app.core.exceptions import UnprocessableEntityError
from BACKEND.app.schemas.kyc import (
    BiometricResult,
    CrossValidationCheck,
    DataSource,
    DeviceMetadataResult,
    DocumentType,
    FinancialData,
    KtpExtractedData,
    KycStatus,
    KycVerificationRequest,
    KycVerificationResponse,
    SimClass,
    SimExtractedData,
    VehicleData,
    VehicleType,
)
from BACKEND.app.services.kyc import ocr, validation
from BACKEND.app.services.kyc import vision


class UploadedPhoto:
    """A single in-memory upload: raw bytes + declared content type."""

    __slots__ = ("raw", "content_type")

    def __init__(self, raw: bytes, content_type: str | None) -> None:
        self.raw = raw
        self.content_type = content_type


class KycService:
    def verify(
        self,
        *,
        request: KycVerificationRequest,
        id_document_photo: UploadedPhoto,
        selfie_photo: UploadedPhoto,
        stnk_photo: UploadedPhoto | None,
        client_ip: str,
        user_agent: str,
    ) -> KycVerificationResponse:
        claimed = request.claimed_identity
        claimed_vehicle = request.claimed_vehicle

        if stnk_photo is None and (
            claimed_vehicle.brand is None
            or claimed_vehicle.model is None
            or claimed_vehicle.year is None
        ):
            raise UnprocessableEntityError(
                "Provide an stnk_photo, or claimed_vehicle.brand/model/year, "
                "so vehicle eligibility can be checked."
            )

        id_image = vision.decode_image(
            id_document_photo.raw,
            field_name="id_document_photo",
            content_type=id_document_photo.content_type,
        )
        selfie_image = vision.decode_image(
            selfie_photo.raw,
            field_name="selfie_photo",
            content_type=selfie_photo.content_type,
        )
        stnk_image = None
        if stnk_photo is not None:
            stnk_image = vision.decode_image(
                stnk_photo.raw,
                field_name="stnk_photo",
                content_type=stnk_photo.content_type,
            )

        id_face_box, id_face_crop = vision.detect_largest_face(id_image)
        selfie_face_box, selfie_face_crop = vision.detect_largest_face(selfie_image)
        id_face_detected = id_face_crop is not None
        selfie_face_detected = selfie_face_crop is not None

        face_match = (
            vision.face_match_score(id_face_crop, selfie_face_crop)
            if id_face_detected and selfie_face_detected
            else 0.0
        )
        liveness = (
            vision.liveness_score(selfie_image, selfie_face_box)
            if selfie_face_detected
            else 0.0
        )
        biometrics = BiometricResult(
            id_face_detected=id_face_detected,
            selfie_face_detected=selfie_face_detected,
            face_match_score=face_match,
            face_match_passed=face_match >= settings.kyc_face_match_threshold,
            liveness_confidence_score=liveness,
            liveness_passed=liveness >= settings.kyc_liveness_threshold,
            verified_at=datetime.now(UTC),
        )

        id_text, id_confidence = ocr.extract_text(
            id_image, field_name="id_document_photo"
        )
        ktp: KtpExtractedData | None = None
        sim: SimExtractedData | None = None
        if request.document_type == DocumentType.KTP:
            ktp = KtpExtractedData(**ocr.parse_ktp(id_text, confidence=id_confidence))
        else:
            sim = SimExtractedData(**ocr.parse_sim(id_text, confidence=id_confidence))

        if stnk_image is not None:
            stnk_text, stnk_confidence = ocr.extract_text(
                stnk_image, field_name="stnk_photo"
            )
            vehicle = VehicleData(**ocr.parse_stnk(stnk_text, confidence=stnk_confidence))
        else:
            vehicle = VehicleData(
                plate_number=claimed_vehicle.plate_number,
                owner_name=claimed.full_name,
                brand=claimed_vehicle.brand,
                model=claimed_vehicle.model,
                year=claimed_vehicle.year,
                color=None,
                tax_valid_until=None,
                source=DataSource.MANUAL,
            )

        extracted_full_name = ktp.full_name if ktp else sim.full_name
        extracted_dob = ktp.date_of_birth if ktp else sim.date_of_birth
        extracted_gender = ktp.gender.value if ktp and ktp.gender else None

        cross_validation, identity_reasons = _check_identity(
            claimed_nik=claimed.nik,
            extracted_nik=ktp.nik if ktp else None,
            claimed_name=claimed.full_name,
            extracted_name=extracted_full_name,
            claimed_dob=claimed.date_of_birth,
            extracted_dob=extracted_dob,
            extracted_gender=extracted_gender,
        )

        sim_class, sim_reasons = _check_sim(
            document_type=request.document_type,
            sim=sim,
            claimed_sim_number=claimed.sim_number,
            claimed_sim_class=claimed.sim_class,
            cross_validation=cross_validation,
        )

        vehicle_reasons = _check_vehicle(
            vehicle=vehicle,
            claimed_vehicle_plate=claimed_vehicle.plate_number,
            vehicle_type=claimed_vehicle.vehicle_type,
            sim_class=sim_class,
            owner_reference_name=extracted_full_name,
            cross_validation=cross_validation,
        )

        age_reasons = _check_age(
            dob=extracted_dob, sim_class=sim_class, min_age=settings.kyc_min_driver_age
        )

        financial_reasons = _check_financial(
            financial=request.financial,
            reference_name=extracted_full_name,
            cross_validation=cross_validation,
        )

        within_area = validation.within_service_area(
            request.device.location.latitude, request.device.location.longitude
        )
        geo_reasons = (
            []
            if within_area
            else ["Reported location is outside the configured service area."]
        )

        biometric_reasons = _check_biometrics(biometrics)

        rejection_reasons = [
            *identity_reasons,
            *sim_reasons,
            *vehicle_reasons,
            *age_reasons,
            *financial_reasons,
            *geo_reasons,
            *biometric_reasons,
        ]

        device = DeviceMetadataResult(
            device_id=request.device.device_id,
            location=request.device.location,
            ip_address=client_ip,
            user_agent=user_agent,
            within_service_area=within_area,
        )

        return KycVerificationResponse(
            request_id=str(uuid.uuid4()),
            status=KycStatus.REJECTED if rejection_reasons else KycStatus.VERIFIED,
            document_type=request.document_type,
            ktp=ktp,
            sim=sim,
            vehicle=vehicle,
            biometrics=biometrics,
            device=device,
            financial=request.financial,
            cross_validation=cross_validation,
            rejection_reasons=rejection_reasons,
            processed_at=datetime.now(UTC),
        )


def _add_check(
    checks: list[CrossValidationCheck],
    *,
    field: str,
    extracted: str | None,
    claimed: str | None,
    matched: bool,
) -> None:
    checks.append(
        CrossValidationCheck(
            field=field, extracted_value=extracted, claimed_value=claimed, matched=matched
        )
    )


def _check_identity(
    *,
    claimed_nik: str,
    extracted_nik: str | None,
    claimed_name: str,
    extracted_name: str,
    claimed_dob: date,
    extracted_dob: date,
    extracted_gender: str | None,
) -> tuple[list[CrossValidationCheck], list[str]]:
    checks: list[CrossValidationCheck] = []
    reasons: list[str] = []

    if extracted_nik is not None:
        nik_matched = extracted_nik == claimed_nik
        _add_check(
            checks,
            field="nik",
            extracted=extracted_nik,
            claimed=claimed_nik,
            matched=nik_matched,
        )
        if not nik_matched:
            reasons.append("NIK on the KTP does not match the claimed NIK.")

    name_matched = validation.names_match(extracted_name, claimed_name)
    _add_check(
        checks,
        field="full_name",
        extracted=extracted_name,
        claimed=claimed_name,
        matched=name_matched,
    )
    if not name_matched:
        reasons.append("Extracted full name does not match the claimed full name.")

    dob_matched = extracted_dob == claimed_dob
    _add_check(
        checks,
        field="date_of_birth",
        extracted=extracted_dob.isoformat(),
        claimed=claimed_dob.isoformat(),
        matched=dob_matched,
    )
    if not dob_matched:
        reasons.append(
            "Extracted date of birth does not match the claimed date of birth."
        )

    nik_dob, nik_gender = validation.parse_nik(claimed_nik)
    if nik_dob is not None:
        nik_dob_matched = nik_dob == claimed_dob
        _add_check(
            checks,
            field="nik_structural_date_of_birth",
            extracted=nik_dob.isoformat(),
            claimed=claimed_dob.isoformat(),
            matched=nik_dob_matched,
        )
        if not nik_dob_matched:
            reasons.append(
                "Date of birth encoded in the NIK does not match the claimed "
                "date of birth."
            )

        if extracted_gender is not None:
            nik_gender_matched = nik_gender == extracted_gender
            _add_check(
                checks,
                field="nik_structural_gender",
                extracted=extracted_gender,
                claimed=nik_gender,
                matched=nik_gender_matched,
            )
            if not nik_gender_matched:
                reasons.append(
                    "Gender encoded in the NIK does not match the gender "
                    "read from the KTP."
                )

    return checks, reasons


def _check_sim(
    *,
    document_type: DocumentType,
    sim: SimExtractedData | None,
    claimed_sim_number: str | None,
    claimed_sim_class: SimClass | None,
    cross_validation: list[CrossValidationCheck],
) -> tuple[SimClass | None, list[str]]:
    reasons: list[str] = []

    if document_type == DocumentType.SIM and sim is not None:
        number_matched = (
            claimed_sim_number is not None and sim.sim_number == claimed_sim_number
        )
        _add_check(
            cross_validation,
            field="sim_number",
            extracted=sim.sim_number,
            claimed=claimed_sim_number,
            matched=number_matched,
        )
        if not number_matched:
            reasons.append(
                "SIM number on the card does not match the claimed SIM number."
            )

        class_matched = (
            claimed_sim_class is not None and sim.sim_class == claimed_sim_class
        )
        _add_check(
            cross_validation,
            field="sim_class",
            extracted=sim.sim_class.value,
            claimed=claimed_sim_class.value if claimed_sim_class else None,
            matched=class_matched,
        )
        if not class_matched:
            reasons.append("SIM class on the card does not match the claimed SIM class.")

        acceptable, days_remaining = validation.sim_expiry_status(sim.valid_until)
        if not acceptable:
            if days_remaining < 0:
                reasons.append(f"SIM expired {-days_remaining} day(s) ago.")
            else:
                reasons.append(
                    f"SIM expires in {days_remaining} day(s), below the "
                    f"{settings.kyc_sim_expiry_warning_days}-day renewal window."
                )

        return sim.sim_class, reasons

    if claimed_sim_class is None:
        reasons.append("SIM class is required to validate vehicle eligibility.")
        return None, reasons

    return claimed_sim_class, reasons


def _check_vehicle(
    *,
    vehicle: VehicleData,
    claimed_vehicle_plate: str,
    vehicle_type: VehicleType,
    sim_class: SimClass | None,
    owner_reference_name: str,
    cross_validation: list[CrossValidationCheck],
) -> list[str]:
    reasons: list[str] = []

    plate_matched = validation.normalize_plate(
        vehicle.plate_number
    ) == validation.normalize_plate(claimed_vehicle_plate)
    _add_check(
        cross_validation,
        field="plate_number",
        extracted=vehicle.plate_number,
        claimed=claimed_vehicle_plate,
        matched=plate_matched,
    )
    if not plate_matched:
        reasons.append("Vehicle plate number does not match the claimed plate number.")

    if not validation.is_valid_plate_format(vehicle.plate_number):
        reasons.append("Vehicle plate number is not a valid Indonesian format.")

    owner_matched = validation.names_match(vehicle.owner_name, owner_reference_name)
    _add_check(
        cross_validation,
        field="vehicle_owner_name",
        extracted=vehicle.owner_name,
        claimed=owner_reference_name,
        matched=owner_matched,
    )
    # Intentionally not a rejection reason: a vehicle owned by someone else
    # is valid with a power-of-attorney letter, which this endpoint can't see.

    if sim_class is not None and not validation.sim_class_matches_vehicle(
        sim_class, vehicle_type
    ):
        reasons.append(
            f"SIM class {sim_class.value} does not authorize a "
            f"{vehicle_type.value} vehicle."
        )

    if not validation.vehicle_age_acceptable(vehicle.year):
        reasons.append(
            f"Vehicle year {vehicle.year} exceeds the "
            f"{settings.kyc_max_vehicle_age_years}-year limit."
        )

    if vehicle.tax_valid_until is None:
        reasons.append("STNK tax validity could not be verified; provide an stnk_photo.")
    elif vehicle.tax_valid_until < date.today():
        reasons.append(f"STNK tax expired on {vehicle.tax_valid_until.isoformat()}.")

    return reasons


def _check_age(*, dob: date, sim_class: SimClass | None, min_age: int) -> list[str]:
    age = validation.calculate_age(dob)
    reasons = []
    if age < min_age:
        reasons.append(f"Driver age {age} is below the minimum age of {min_age}.")
    if sim_class is not None:
        required = validation.min_age_for_sim_class(sim_class)
        if age < required:
            reasons.append(
                f"Driver age {age} is below the minimum age of {required} "
                f"required for SIM {sim_class.value}."
            )
    return reasons


def _check_financial(
    *,
    financial: FinancialData | None,
    reference_name: str,
    cross_validation: list[CrossValidationCheck],
) -> list[str]:
    if financial is None:
        return []

    reasons: list[str] = []
    holder_matched = validation.normalize_name(
        financial.bank_account_holder_name
    ) == validation.normalize_name(reference_name)
    _add_check(
        cross_validation,
        field="bank_account_holder_name",
        extracted=reference_name,
        claimed=financial.bank_account_holder_name,
        matched=holder_matched,
    )
    if not holder_matched:
        reasons.append(
            "Bank account holder name does not match the verified identity name."
        )

    if (
        financial.skck_valid_until is not None
        and financial.skck_valid_until < date.today()
    ):
        reasons.append(f"SKCK expired on {financial.skck_valid_until.isoformat()}.")

    return reasons


def _check_biometrics(biometrics: BiometricResult) -> list[str]:
    reasons = []
    if not biometrics.id_face_detected:
        reasons.append("No face could be detected on the identity document photo.")
    if not biometrics.selfie_face_detected:
        reasons.append("No face could be detected in the live selfie photo.")
    if (
        biometrics.id_face_detected
        and biometrics.selfie_face_detected
        and not biometrics.face_match_passed
    ):
        reasons.append(
            f"Face match score {biometrics.face_match_score:.2f} is below the "
            f"{settings.kyc_face_match_threshold:.2f} threshold."
        )
    if biometrics.selfie_face_detected and not biometrics.liveness_passed:
        reasons.append(
            f"Liveness confidence {biometrics.liveness_confidence_score:.2f} "
            f"is below the {settings.kyc_liveness_threshold:.2f} threshold."
        )
    return reasons


kyc_service = KycService()
