"""Genera propuestas visuales desde un único isotipo vectorial.

No modifica recursos usados por Flutter ni Android. Requiere ImageMagick y Pillow.
"""

from __future__ import annotations

import hashlib
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets/branding/sky/isotipo-master.svg"
OUTPUT = ROOT / "design/cercly-sky"
SVG_DIR = OUTPUT / "svg"
PNG_DIR = OUTPUT / "previews"
FLUTTER_DIR = ROOT / "assets/branding/sky/variants"
FONT = ROOT / "assets/branding/sky/fonts/Comfortaa-Bold.otf"

# Valores finales propuestos para el logo; la interfaz conserva SkyPalette.
# (nombre, marca inicio, marca centro, marca fin, fondo inicio, fondo fin,
#  texto sobre fondo claro, texto sobre fondo oscuro)
PALETTES = {
    "amanecer": (
        "Amanecer", "#20A7F5", "#887AF0", "#FF9C78",
        "#D0D7FF", "#FFD6C3", "#14265A", "#FFFFFF",
    ),
    "dia": (
        "Día", "#0066ED", "#17B9F5", "#0067DC",
        "#E8F6FF", "#BEEBFF", "#102A62", "#FFFFFF",
    ),
    "atardecer": (
        "Atardecer", "#FFB148", "#F05586", "#7935D1",
        "#FFF0D8", "#FFC7D5", "#321C62", "#FFFFFF",
    ),
    "noche": (
        "Noche", "#E1C4FF", "#8F92FA", "#5C8BFF",
        "#283D83", "#0B1E4D", "#182450", "#FFFFFF",
    ),
}


def svg(view_box: str, body: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{view_box}" role="img">\n{body}\n</svg>\n'
    )


def save(name: str, content: str) -> Path:
    path = SVG_DIR / name
    path.write_text(content, encoding="utf-8")
    if name.startswith("isotipo-"):
        FLUTTER_DIR.mkdir(parents=True, exist_ok=True)
        (FLUTTER_DIR / name).write_text(content, encoding="utf-8")
    return path


def render(source: Path, target: Path, size: int) -> None:
    subprocess.run(
        ["magick", "-background", "none", "-density", "288", str(source),
         "-resize", f"{size}x{size}", str(target)],
        check=True,
        capture_output=True,
        text=True,
    )


def main() -> None:
    SVG_DIR.mkdir(parents=True, exist_ok=True)
    PNG_DIR.mkdir(parents=True, exist_ok=True)
    tree = ET.parse(MASTER)
    root = tree.getroot()
    namespace = "{http://www.w3.org/2000/svg}"
    path = root.find(f"{namespace}path[@id='c-pin']")
    dot = root.find(f"{namespace}circle[@id='location-dot']")
    assert root.attrib["viewBox"] == "0 0 256 256" and path is not None
    assert dot is not None and len(root) == 2
    geometry = path.attrib["d"]
    dot_geometry = (dot.attrib["cx"], dot.attrib["cy"], dot.attrib["r"])
    geometry_digest = hashlib.sha256(
        (geometry + "|" + "|".join(dot_geometry)).encode()
    ).hexdigest()

    for key, (title, first, middle, last, bg1, bg2, light, dark) in PALETTES.items():
        wordmark_color = dark if key == "noche" else light
        mark_gradient = (
            '<defs><linearGradient id="mark" x1="0" y1="0" x2="0.8" y2="1">'
            f'<stop offset="0" stop-color="{first}"/>'
            f'<stop offset="0.51" stop-color="{middle}"/>'
            f'<stop offset="1" stop-color="{last}"/>'
            '</linearGradient></defs>'
        )
        background_gradient = (
            '<defs><linearGradient id="background" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{bg1}"/>'
            f'<stop offset="1" stop-color="{bg2}"/>'
            '</linearGradient></defs>'
        )
        mark = (
            f'<path id="c-pin" d="{geometry}" fill="url(#mark)"/>'
            f'<circle id="location-dot" cx="{dot_geometry[0]}" '
            f'cy="{dot_geometry[1]}" r="{dot_geometry[2]}" fill="url(#mark)"/>'
        )
        solid_mark = (
            f'<path id="c-pin" d="{geometry}" fill="#000000"/>'
            f'<circle id="location-dot" cx="{dot_geometry[0]}" '
            f'cy="{dot_geometry[1]}" r="{dot_geometry[2]}" fill="#000000"/>'
        )
        save(f"isotipo-{key}.svg", svg("0 0 256 256", mark_gradient + mark))
        save(
            f"horizontal-{key}.svg",
            svg(
                "0 0 620 220",
                mark_gradient +
                '<g transform="translate(12 0) scale(0.84)">' + mark + '</g>' +
                f'<text x="225" y="140" font-family="Comfortaa" '
                f'font-size="69" font-weight="bold" fill="{wordmark_color}" '
                f'stroke="{wordmark_color}" stroke-width="1.5" '
                'stroke-linejoin="round">Cercly</text>',
            ),
        )
        save(
            f"icono-{key}.svg",
            svg(
                "0 0 432 432",
                background_gradient + mark_gradient +
                '<rect width="432" height="432" rx="96" fill="url(#background)"/>' +
                '<g transform="translate(88 88)">' + mark + '</g>',
            ),
        )
        save(
            f"adaptativo-frente-{key}.svg",
            svg("0 0 432 432", mark_gradient +
                '<g transform="translate(88 88)">' + mark + '</g>'),
        )
        save(
            f"adaptativo-fondo-{key}.svg",
            svg("0 0 432 432", background_gradient +
                '<rect width="432" height="432" fill="url(#background)"/>'),
        )
        save(
            f"monocromo-{key}.svg",
            svg("0 0 432 432", '<g transform="translate(88 88)">' +
                solid_mark + '</g>'),
        )
        render(SVG_DIR / f"isotipo-{key}.svg", PNG_DIR / f"isotipo-{key}.png", 768)
        render(SVG_DIR / f"horizontal-{key}.svg", PNG_DIR / f"horizontal-{key}.png", 900)
        render(SVG_DIR / f"icono-{key}.svg", PNG_DIR / f"icono-{key}.png", 768)
        render(SVG_DIR / f"adaptativo-frente-{key}.svg", PNG_DIR / f"adaptativo-frente-{key}.png", 432)
        render(SVG_DIR / f"monocromo-{key}.svg", PNG_DIR / f"monocromo-{key}.png", 432)

    # Verificación de la geometría en el XML y en las máscaras rasterizadas.
    base_mask = None
    for key in PALETTES:
        variant = ET.parse(SVG_DIR / f"isotipo-{key}.svg").getroot()
        variant_path = variant.find(f"{namespace}path[@id='c-pin']")
        variant_dot = variant.find(f"{namespace}circle[@id='location-dot']")
        assert variant_path is not None and variant_path.attrib["d"] == geometry
        assert variant_dot is not None
        assert tuple(variant_dot.attrib[name] for name in ("cx", "cy", "r")) == dot_geometry
        alpha = Image.open(PNG_DIR / f"isotipo-{key}.png").convert("RGBA").getchannel("A")
        if base_mask is not None:
            assert ImageChops.difference(base_mask, alpha).getbbox() is None
        base_mask = alpha
        foreground = Image.open(PNG_DIR / f"adaptativo-frente-{key}.png").convert("RGBA")
        pixels = foreground.getchannel("A")
        for y in range(432):
            for x in range(432):
                if pixels.getpixel((x, y)) > 0:
                    assert (x - 216) ** 2 + (y - 216) ** 2 < 144 ** 2

    create_sheet()
    print(f"Geometría idéntica en cuatro variantes: SHA-256 {geometry_digest}")
    print(f"Lámina: {PNG_DIR / 'comparativa-cercly-sky.png'}")


def create_sheet() -> None:
    font_title = ImageFont.truetype(str(FONT), 36)
    font_sub = ImageFont.truetype(str(FONT), 20)
    font_small = ImageFont.truetype(str(FONT), 17)
    width, height = 1880, 1260
    sheet = Image.new("RGB", (width, height), "#F3F6FC")
    draw = ImageDraw.Draw(sheet)
    draw.text((44, 26), "Cercly Sky — propuesta vectorial", fill="#13264D", font=font_title)
    draw.text((45, 77), "Misma geometría · cuatro ambientes · sin fotografías", fill="#516380", font=font_sub)

    for index, (key, (title, *colors)) in enumerate(PALETTES.items()):
        x = 35 + index * 464
        draw.rounded_rectangle((x, 128, x + 445, 1220), radius=28, fill="white")
        draw.text((x + 24, 148), title, fill="#142650", font=font_title)
        draw.text((x + 25, 203), "Isotipo sin fondo", fill="#536582", font=font_sub)

        checker = Image.new("RGB", (390, 265), "white")
        check_draw = ImageDraw.Draw(checker)
        for row in range(0, 265, 22):
            for col in range(0, 390, 22):
                if (row // 22 + col // 22) % 2 == 0:
                    check_draw.rectangle((col, row, col + 21, row + 21), fill="#E6EBF4")
        icon = Image.open(PNG_DIR / f"isotipo-{key}.png").convert("RGBA")
        icon.thumbnail((235, 235), Image.Resampling.LANCZOS)
        checker.paste(icon, ((390 - icon.width) // 2, 14), icon)
        sheet.paste(checker, (x + 27, 242))

        draw.text((x + 25, 528), "Icono Android preliminar", fill="#536582", font=font_sub)
        app_icon = Image.open(PNG_DIR / f"icono-{key}.png").convert("RGBA")
        app_icon.thumbnail((265, 265), Image.Resampling.LANCZOS)
        sheet.paste(app_icon, (x + 90, 568), app_icon)

        draw.text((x + 25, 858), "Logotipo horizontal", fill="#536582", font=font_sub)
        horizontal = Image.open(PNG_DIR / f"horizontal-{key}.png").convert("RGBA")
        horizontal.thumbnail((390, 139), Image.Resampling.LANCZOS)
        if key == "noche":
            draw.rounded_rectangle((x + 20, 890, x + 425, 1034), radius=18, fill="#0B1E4D")
        sheet.paste(horizontal, (x + 27, 894), horizontal)

        draw.text((x + 25, 1044), "Prueba a tamaño real", fill="#536582", font=font_sub)
        for size, offset in ((24, 40), (48, 135), (96, 255)):
            miniature = Image.open(PNG_DIR / f"icono-{key}.png").convert("RGBA")
            miniature = miniature.resize((size, size), Image.Resampling.LANCZOS)
            sheet.paste(miniature, (x + offset, 1093), miniature)
            draw.text((x + offset, 1195), f"{size} px", fill="#536582", font=font_small)

    sheet.save(PNG_DIR / "comparativa-cercly-sky.png", optimize=True)


if __name__ == "__main__":
    main()
