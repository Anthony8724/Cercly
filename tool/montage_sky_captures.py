"""Crea láminas comparativas desde capturas Flutter con datos sintéticos."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "design/cercly-sky/capturas"
FONT = ROOT / "assets/branding/sky/fonts/Comfortaa-Bold.otf"
SCREENS = (
    "bienvenida",
    "login",
    "registro",
    "mi-cuenta",
    "explorar-cabecera",
    "explorar",
    "mapa-sin-ubicacion",
)
ENVIRONMENTS = (
    ("amanecer", "Amanecer"),
    ("dia", "Día"),
    ("atardecer", "Atardecer"),
    ("noche", "Noche"),
)


def main() -> None:
    font = ImageFont.truetype(str(FONT), 26)
    title = ImageFont.truetype(str(FONT), 30)
    for screen in SCREENS:
        canvas = Image.new("RGB", (1660, 980), "#E9EEF8")
        draw = ImageDraw.Draw(canvas)
        draw.text((24, 15), f"Cercly Sky · {screen}", font=title, fill="#152650")
        for index, (environment, label) in enumerate(ENVIRONMENTS):
            x = 20 + index * 410
            draw.text((x, 63), label, font=font, fill="#243A6C")
            source = Image.open(FOLDER / f"{screen}-{environment}.png").convert("RGB")
            source = source.resize((390, 844), Image.Resampling.LANCZOS)
            canvas.paste(source, (x, 109))
        canvas.save(FOLDER / f"comparativa-{screen}.png", optimize=True)


if __name__ == "__main__":
    main()
