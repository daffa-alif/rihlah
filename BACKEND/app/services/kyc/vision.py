"""In-memory image processing: decode, face detection, face match, liveness.

Everything here operates on bytes/arrays that live only for the duration of
one request. Nothing is written to disk, cached, or logged. Callers are
responsible for letting the raw bytes go out of scope once processing is
done — there is no persistence path in this module to opt out of.

Face matching uses classical OpenCV signals (histogram + ORB keypoint
correlation), not a deep-learning face embedding model — the project has no
GPU/vendor dependency to lean on for that. Liveness (see
analyze_liveness_frames) is behavior-based across a burst of frames — blink
detection + natural face-position drift + average sharpness — rather than a
single-frame heuristic, since a lone photo can trivially fake one still
frame but not a genuine blink across many. Both are explainable and fully
offline, but not biometric-grade; treat the thresholds in Settings as a
starting point and swap in a proper face-recognition/liveness SDK before
relying on this for production-grade fraud prevention.
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
_EYE_CASCADE = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_eye.xml")


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


def _frame_sharpness_score(gray_face: np.ndarray) -> float:
    """Single-face-crop sharpness proxy in [0, 1] (higher = crisper).

    A printed/re-photographed or screen-replayed face tends to be softer
    than a live capture — this alone isn't liveness proof (see
    analyze_liveness_frames for the behavior signals that matter more), but
    it's one contributing signal, averaged across frames.
    """
    sharpness = cv2.Laplacian(gray_face, cv2.CV_64F).var()
    return min(1.0, sharpness / 150.0)


def _count_eyes(gray_face: np.ndarray) -> int:
    """Number of eyes detected inside a face crop (0, 1, or 2+)."""
    eyes = _EYE_CASCADE.detectMultiScale(
        gray_face, scaleFactor=1.1, minNeighbors=8, minSize=(15, 15)
    )
    return len(eyes)


class LivenessFrameAnalysis:
    """Result of analyze_liveness_frames — plain data, not a pydantic model
    (vision.py stays schema-agnostic; app/services/kyc/service.py maps this
    onto LivenessBehaviorResult, same pattern as ocr.py's parse_* -> dict)."""

    __slots__ = (
        "frames_received",
        "frames_with_face",
        "blink_detected",
        "motion_score",
        "sharpness_score",
        "liveness_confidence_score",
        "best_face_crop",
    )

    def __init__(
        self,
        *,
        frames_received: int,
        frames_with_face: int,
        blink_detected: bool,
        motion_score: float,
        sharpness_score: float,
        liveness_confidence_score: float,
        best_face_crop: np.ndarray | None,
    ) -> None:
        self.frames_received = frames_received
        self.frames_with_face = frames_with_face
        self.blink_detected = blink_detected
        self.motion_score = motion_score
        self.sharpness_score = sharpness_score
        self.liveness_confidence_score = liveness_confidence_score
        self.best_face_crop = best_face_crop


def analyze_liveness_frames(frames: list[np.ndarray]) -> LivenessFrameAnalysis:
    """Behavior-based liveness across an ordered burst of live-captured
    selfie frames (client-extracted from a couple of seconds of video —
    see app/services/kyc/service.py for how many frames are required).

    Looks for signals a single static photo or a screen replay can't
    reliably produce:

    - **Blink**: an eyes-detected -> eyes-not-detected -> eyes-detected
      transition across consecutive frames with a face. A held-up photo
      shows the same (open or closed) eye state in every frame.
    - **Motion**: the detected face position naturally drifts a little
      frame to frame from hand/head micro-movement; a perfectly static box
      across every single frame is itself a little suspicious.
    - **Sharpness**: same single-frame proxy as before (see
      _frame_sharpness_score), averaged over the frames with a face.

    Still classical OpenCV heuristics, not a dedicated anti-spoofing model
    — see the module docstring. `liveness_confidence_score` blends the
    three; app/services/kyc/service.py additionally requires an actual
    detected blink before it will call liveness "passed" (see
    settings.kyc_require_blink), since the blend alone can be fooled by a
    lucky combination of motion+sharpness without any real blink.
    """
    frames_received = len(frames)
    eye_open_sequence: list[bool] = []
    centers: list[tuple[float, float]] = []
    sharpness_scores: list[float] = []
    best_face_crop: np.ndarray | None = None
    best_sharpness = -1.0

    for frame in frames:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        gray = cv2.equalizeHist(gray)
        faces = _FACE_CASCADE.detectMultiScale(
            gray, scaleFactor=1.1, minNeighbors=5, minSize=(60, 60)
        )
        if len(faces) == 0:
            continue

        x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
        face_crop = gray[y : y + h, x : x + w]

        centers.append((x + w / 2, y + h / 2))
        eye_open_sequence.append(_count_eyes(face_crop) >= 2)

        sharpness = _frame_sharpness_score(face_crop)
        sharpness_scores.append(sharpness)
        if sharpness > best_sharpness:
            best_sharpness = sharpness
            best_face_crop = face_crop

    frames_with_face = len(centers)

    blink_detected = False
    for i in range(1, len(eye_open_sequence) - 1):
        was_open = eye_open_sequence[i - 1]
        is_closed = not eye_open_sequence[i]
        reopened = eye_open_sequence[i + 1]
        if was_open and is_closed and reopened:
            blink_detected = True
            break

    motion_score = 0.0
    if len(centers) >= 2:
        xs = [c[0] for c in centers]
        ys = [c[1] for c in centers]
        spread = (float(np.std(xs)) ** 2 + float(np.std(ys)) ** 2) ** 0.5
        # A few pixels of natural drift is expected; scale so ~15px+ of
        # combined drift reads as fully "in motion" (heuristic constant,
        # tune against real capture data before relying on this in prod).
        motion_score = max(0.0, min(1.0, spread / 15.0))

    sharpness_score = 0.0
    if sharpness_scores:
        sharpness_score = round(sum(sharpness_scores) / len(sharpness_scores), 4)

    liveness_confidence_score = round(
        0.45 * (1.0 if blink_detected else 0.0)
        + 0.30 * motion_score
        + 0.25 * sharpness_score,
        4,
    )

    return LivenessFrameAnalysis(
        frames_received=frames_received,
        frames_with_face=frames_with_face,
        blink_detected=blink_detected,
        motion_score=round(motion_score, 4),
        sharpness_score=sharpness_score,
        liveness_confidence_score=liveness_confidence_score,
        best_face_crop=best_face_crop,
    )
