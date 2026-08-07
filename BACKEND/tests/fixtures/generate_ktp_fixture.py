"""Regenerates tests/fixtures/sample_ktp.jpg — a synthetic KTP image whose
printed fields match the regex layout app/services/kyc/ocr.py expects, so
the OCR parser can actually be exercised in tests without a real KTP photo.

Not a test itself, and not run automatically — this is a placeholder/test
fixture, not a real Indonesian ID (the NIK/name/address are all made up).
Re-run manually (`python tests/fixtures/generate_ktp_fixture.py`) if the
layout ever needs to change; the committed .jpg is what tests actually load.

The NIK's own digits (317301 + 150599 + 0001) are chosen to structurally
encode 1999-05-15 / male, matching the "Tempat/Tgl Lahir" and "Jenis
Kelamin" lines below — so a test can also check the NIK self-consistency
path (see service.py's _check_nik_self_consistency) against this fixture.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

LINES = [
    "PROVINSI DKI JAKARTA",
    "KOTA JAKARTA PUSAT",
    "",
    "NIK : 3173011505990001",
    "Nama : BUDI SANTOSO",
    "Tempat/Tgl Lahir : JAKARTA, 15-05-1999",
    "Jenis Kelamin : LAKI-LAKI",
    "Alamat : JL. MERDEKA NO. 17",
    "RT/RW : 003/005",
    "Kel/Desa : CIKINI",
    "Kecamatan : MENTENG",
    "Agama : ISLAM",
    "Status Perkawinan : BELUM KAWIN",
    "Pekerjaan : KARYAWAN SWASTA",
    "Kewarganegaraan : WNI",
    "Berlaku Hingga : SEUMUR HIDUP",
]


def _load_font(size: int) -> ImageFont.FreeTypeFont:
    for candidate in (
        "C:/Windows/Fonts/consola.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
    ):
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default(size=size)


def main() -> None:
    width, height = 1200, 760
    image = Image.new("RGB", (width, height), color="white")
    draw = ImageDraw.Draw(image)
    font = _load_font(30)

    y = 40
    line_height = 40
    for line in LINES:
        draw.text((50, y), line, fill="black", font=font)
        y += line_height

    out_path = Path(__file__).parent / "sample_ktp.jpg"
    image.save(out_path, quality=95)
    print(f"written {out_path} ({out_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
