"""Compone fotogramas renderizados por Flutter; no genera imágenes conceptuales."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "design/cercly-sky/capturas/animacion"
FONT = ROOT / "assets/branding/sky/fonts/Comfortaa-Bold.otf"
ENVIRONMENTS = ("amanecer", "dia", "atardecer", "noche")
LABELS = ("Amanecer", "Día", "Atardecer", "Noche")
SECONDS = (0, 2, 4, 6)


def frame_at(second: int) -> Image.Image:
    canvas = Image.new("RGB", (1640, 900), "#E9EEF8")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(str(FONT), 21)
    for index, (environment, label) in enumerate(zip(ENVIRONMENTS, LABELS)):
        x = 16 + index * 406
        draw.text((x, 15), f"{label} · {second} s", font=font, fill="#152650")
        source = Image.open(FOLDER / f"{environment}-{second}s.png").convert("RGB")
        canvas.paste(source, (x, 48))
    return canvas


def main() -> None:
    frames = [frame_at(second) for second in SECONDS]
    frames[0].save(FOLDER / "comparativa-inicial.png", optimize=True)
    frames[0].save(
        FOLDER / "secuencia-cercly-sky.gif",
        save_all=True,
        append_images=frames[1:],
        duration=[2000] * len(frames),
        loop=0,
        optimize=True,
    )


if __name__ == "__main__":
    main()
