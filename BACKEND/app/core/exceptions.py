from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import ValidationError as PydanticValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

# Spelled out rather than taken from `status`: the constant was renamed
# UNPROCESSABLE_ENTITY -> UNPROCESSABLE_CONTENT across Starlette versions.
HTTP_422 = 422


class AppError(Exception):
    """Base class for errors raised by the service layer."""

    status_code: int = status.HTTP_400_BAD_REQUEST
    code: str = "app_error"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "not_found"


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT
    code = "conflict"


class UnsupportedMediaTypeError(AppError):
    status_code = status.HTTP_415_UNSUPPORTED_MEDIA_TYPE
    code = "unsupported_media_type"


class PayloadTooLargeError(AppError):
    status_code = 413
    code = "payload_too_large"


class UnprocessableEntityError(AppError):
    """Well-formed request that couldn't be processed (e.g. undecodable image)."""

    status_code = HTTP_422
    code = "unprocessable_entity"


class ServiceUnavailableError(AppError):
    """A required external dependency (e.g. the Tesseract OCR engine) is missing."""

    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    code = "service_unavailable"


def _error_body(code: str, message: str, details: object | None = None) -> dict:
    body: dict = {"error": {"code": code, "message": message}}
    if details is not None:
        body["error"]["details"] = details
    return body


def register_exception_handlers(app: FastAPI) -> None:
    """Attach handlers so every error response shares one JSON shape."""

    @app.exception_handler(AppError)
    async def handle_app_error(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_body(exc.code, exc.message),
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_error(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_body("http_error", str(exc.detail)),
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        _: Request, exc: RequestValidationError
    ) -> JSONResponse:
        # errors() can embed raw exception objects under "ctx" — encode first.
        return JSONResponse(
            status_code=HTTP_422,
            content=_error_body(
                "validation_error",
                "Request payload failed validation.",
                jsonable_encoder(exc.errors()),
            ),
        )

    @app.exception_handler(PydanticValidationError)
    async def handle_pydantic_error(
        _: Request, exc: PydanticValidationError
    ) -> JSONResponse:
        # Raised when a route manually parses a JSON form field (see
        # app/api/routes/kyc.py) rather than letting FastAPI parse the body.
        return JSONResponse(
            status_code=HTTP_422,
            content=_error_body(
                "validation_error",
                "Request payload failed validation.",
                jsonable_encoder(exc.errors()),
            ),
        )
