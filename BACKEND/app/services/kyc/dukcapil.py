"""Dukcapil (Indonesian civil registry / Direktorat Jenderal Kependudukan dan
Pencatatan Sipil) identity confirmation — currently a stub.

This project has no real Dukcapil API credential. `confirm_identity()` below
is the seam a real integration plugs into: it takes exactly what a real call
would take (NIK, name, date of birth — all read off the KTP by OCR, never
typed by the driver) and returns exactly the shape a real call would return
(`DukcapilConfirmationResult`). Swapping the body of this function for an
authenticated HTTP call to the actual Dukcapil NIK-verification API is the
only change a real integration should require — nothing in
app/services/kyc/service.py needs to know the difference.

Until then, this always reports the OCR-extracted identity back as
`MATCHED` (`source="STUB"`) rather than silently fabricating a "verified by
Dukcapil" claim the project can't back up — every response makes clear it
came from the stub, not a real registry check.
"""

from datetime import UTC, date, datetime

from BACKEND.app.schemas.kyc import DukcapilConfirmationResult, DukcapilStatus


def confirm_identity(
    *, nik: str | None, full_name: str | None, date_of_birth: date | None
) -> DukcapilConfirmationResult:
    """Confirm an OCR-extracted identity against Dukcapil.

    Returns `UNAVAILABLE` if there's no NIK to check (e.g. the identity
    document wasn't a KTP). Otherwise always `MATCHED` for now — see the
    module docstring for why, and `source="STUB"` for the honesty marker
    that distinguishes this from a real registry response.
    """
    if not nik:
        return DukcapilConfirmationResult(
            status=DukcapilStatus.UNAVAILABLE,
            nik=None,
            full_name=full_name,
            checked_at=datetime.now(UTC),
            source="STUB",
            notes=(
                "No NIK was available to check (Dukcapil confirmation "
                "requires a KTP as the identity document)."
            ),
        )

    # A real integration would do something like:
    #   response = httpx.post(
    #       f"{settings.kyc_dukcapil_base_url}/nik/verify",
    #       headers={"Authorization": f"Bearer {settings.kyc_dukcapil_api_key}"},
    #       json={"nik": nik, "full_name": full_name, "dob": str(date_of_birth)},
    #   )
    #   ... map response -> DukcapilStatus.MATCHED / NOT_FOUND / MISMATCH ...
    # settings.kyc_dukcapil_base_url/kyc_dukcapil_api_key already exist for
    # that, but are unused here — there is nothing to call yet.
    return DukcapilConfirmationResult(
        status=DukcapilStatus.MATCHED,
        nik=nik,
        full_name=full_name,
        checked_at=datetime.now(UTC),
        source="STUB",
        notes=(
            "No live Dukcapil integration is configured; this echoes the "
            "OCR-extracted identity rather than a real registry check."
        ),
    )
