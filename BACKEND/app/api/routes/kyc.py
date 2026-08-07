from typing import Annotated

from fastapi import APIRouter, File, Form, Request, UploadFile, status

from BACKEND.app.api.deps import KycServiceDep
from BACKEND.app.core.config import settings
from BACKEND.app.schemas.common import ErrorResponse
from BACKEND.app.schemas.kyc import KycVerificationRequest, KycVerificationResponse
from BACKEND.app.services.kyc.service import UploadedPhoto

router = APIRouter(
    prefix="/kyc",
    tags=["kyc"],
    responses={422: {"model": ErrorResponse, "description": "Validation error"}},
)

PayloadField = Annotated[
    str, Form(description="JSON-encoded KycVerificationRequest (see schema).")
]
IdDocumentPhotoField = Annotated[
    UploadFile, File(description="Live photo of the KTP or SIM.")
]
SelfieFramesField = Annotated[
    list[UploadFile],
    File(
        description=(
            "Ordered live-captured selfie frames (a short burst/video "
            "extracted client-side, e.g. by the Flutter app) for "
            "frame-by-frame liveness analysis. "
            f"{settings.kyc_min_liveness_frames}-"
            f"{settings.kyc_max_liveness_frames} frames."
        )
    ),
]
StnkPhotoField = Annotated[
    UploadFile | None,
    File(description="Optional live photo of the STNK for vehicle data."),
]


@router.post(
    "/verify",
    response_model=KycVerificationResponse,
    status_code=status.HTTP_200_OK,
    summary="Run a one-shot driver KYC verification",
    description=(
        "Accepts a live-captured identity document photo (KTP or SIM), an "
        "ordered burst of live selfie frames for frame-by-frame liveness "
        "analysis, and an optional STNK photo. Identity (NIK/name/date of "
        "birth) is read entirely from the document via OCR and confirmed "
        "against Dukcapil — nothing about it is driver-typed. Every photo/"
        "frame is decoded in memory, processed exactly once for this single "
        "request, and discarded — none are written to disk, cached, or "
        "persisted in any datastore."
    ),
    responses={
        413: {"model": ErrorResponse, "description": "A photo exceeds the size limit"},
        415: {"model": ErrorResponse, "description": "A photo has an unsupported type"},
        422: {"model": ErrorResponse, "description": "Payload or document data invalid"},
        503: {"model": ErrorResponse, "description": "The OCR engine is unavailable"},
    },
)
async def verify_kyc(
    request: Request,
    service: KycServiceDep,
    payload: PayloadField,
    id_document_photo: IdDocumentPhotoField,
    selfie_frames: SelfieFramesField,
    stnk_photo: StnkPhotoField = None,
) -> KycVerificationResponse:
    parsed_payload = KycVerificationRequest.model_validate_json(payload)

    id_bytes = await id_document_photo.read()
    selfie_uploads = [
        UploadedPhoto(await frame.read(), frame.content_type) for frame in selfie_frames
    ]
    stnk_upload = None
    if stnk_photo is not None:
        stnk_bytes = await stnk_photo.read()
        stnk_upload = UploadedPhoto(stnk_bytes, stnk_photo.content_type)

    return service.verify(
        request=parsed_payload,
        id_document_photo=UploadedPhoto(id_bytes, id_document_photo.content_type),
        selfie_frames=selfie_uploads,
        stnk_photo=stnk_upload,
        client_ip=request.client.host if request.client else "unknown",
        user_agent=request.headers.get("user-agent", "unknown"),
    )
