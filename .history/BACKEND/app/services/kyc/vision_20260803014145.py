"""In-memory image processing: decode, face detection, face match, liveness.

Everything here operates on bytes/arrays that live only for the duration of
one request. Nothing is written to disk, cached, or logged. Callers are
responsible for letting the raw bytes go out of scope once processing is
done — there is no persistence path in this module to opt out of.

Face matching and liveness use classical OpenCV signals (histogram + ORB
keypoint correlation, sharpness/frequency analysis), not a deep-learning face
embedding model — the project has no GPU/vendor dependency to lean on for
that. That makes both scores explainable and fully offline, but not
biometric-grade; treat the thresholds in Settings as a starting point and
swap in a proper face-recognition/liveness SDK before relying on this for
production-grade fraud prevention.
"""

import cv2
import numpy as np

from BACKEND.app.core.config import settings
from BACKEND.app.core.exceptions import (
    PayloadTooLargeError,
    UnprocessableEntityError,
    UnsupportedMediaTypeError,
)

FaceBox = tuple[int, int, int, int]

_FACE_CASCADE = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)


def decode_image(raw: bytes, *, field_name: str, content_type: str | None) -> np.ndarray:
    """Decode raw upload bytes straight into an in-memory BGR array."""
    if content_type not in settings.kyc_allowed_content_types:
        raise UnsupportedMediaTypeError(
            f"{field_name} must be one of {settings.kyc_allowed_content_types}, "
            f"got '{content_type}'."
        )
    if not raw:
        raise UnprocessableEntityError(f"{field_name} is empty.")
    if len(raw) > settings.kyc_max_upload_bytes:
        raise PayloadTooLargeError(
            f"{field_name} exceeds the {settings.kyc_max_upload_mb}MB limit."
        )

    buffer = np.frombuffer(raw, dtype=np.uint8)
    image = cv2.imdecode(buffer, cv2.IMREAD_COLOR)
    if image is None:
        raise UnprocessableEntityError(f"{field_name} could not be decoded as an image.")
    return image


def detect_largest_face(image: np.ndarray) -> tuple[FaceBox | None, np.ndarray | None]:
    """Return the largest detected face as (box, grayscale crop), or (None, None)."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)
    faces = _FACE_CASCADE.detectMultiScale(
        gray, scaleFactor=1.1, minNeighbors=5, minSize=(60, 60)
    )
    if len(faces) == 0:
        return None, None

    x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
    box: FaceBox = (int(x), int(y), int(w), int(h))
    crop = gray[y : y + h, x : x + w]
    return box, crop


def face_match_score(face_a: np.ndarray, face_b: np.ndarray) -> float:
    """Similarity in [0, 1] between two grayscale face crops.

    Blends grayscale-histogram correlation with ORB keypoint match ratio —
    two independent, complementary classical signals, averaged to reduce
    either one's blind spots.
    """
    size = (200, 200)
    a = cv2.equalizeHist(cv2.resize(face_a, size))
    b = cv2.equalizeHist(cv2.resize(face_b, size))

    hist_a = cv2.calcHist([a], [0], None, [256], [0, 256])
    hist_b = cv2.calcHist([b], [0], None, [256], [0, 256])
    cv2.normalize(hist_a, hist_a)
    cv2.normalize(hist_b, hist_b)
    correlation = cv2.compareHist(hist_a, hist_b, cv2.HISTCMP_CORREL)
    hist_score = max(0.0, min(1.0, (correlation + 1) / 2))

    orb = cv2.ORB_create(nfeatures=500)
    kp_a, des_a = orb.detectAndCompute(a, None)
    kp_b, des_b = orb.detectAndCompute(b, None)
    orb_score = 0.0
    if des_a is not None and des_b is not None and len(kp_a) and len(kp_b):
        matcher = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
        matches = matcher.match(des_a, des_b)
        good = [m for m in matches if m.distance < 60]
        orb_score = min(1.0, len(good) / max(1, min(len(kp_a), len(kp_b))))

    return round(0.5 * hist_score + 0.5 * orb_score, 4)


def liveness_score(image: np.ndarray, face_box: FaceBox) -> float:
    """Single-frame anti-spoofing proxy in [0, 1].

    Combines image sharpness (a printed/re-photographed face tends to be
    softer than a live capture) with a high-frequency energy penalty (screen
    replays commonly show moire/pixel-grid artifacts). This is a heuristic
    stand-in for real liveness detection, which normally needs multiple
    frames (blink/head-turn challenge) or a dedicated anti-spoofing model.
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    x, y, w, h = face_box
    face = gray[y : y + h, x : x + w]

    sharpness = cv2.Laplacian(face, cv2.CV_64F).var()
    sharpness_score = min(1.0, sharpness / 150.0)

    spectrum = np.fft.fftshift(np.fft.fft2(face))
    magnitude = np.log(np.abs(spectrum) + 1)
    fh, fw = magnitude.shape
    cy, cx = fh // 2, fw // 2
    half = 5
    high_freq_energy = float(
        magnitude[cy - half : cy + half, cx - half : cx + half].mean()
    )
    moire_penalty = max(0.0, min(1.0, (high_freq_energy - 8) / 4))

    score = max(0.0, min(1.0, sharpness_score * (1 - 0.5 * moire_penalty)))
    return round(score, 4)
