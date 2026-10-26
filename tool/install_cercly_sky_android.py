"""Instala los iconos Android desde los SVG aprobados generados.

La variante Día queda fija como icono principal. No activa cambios dinámicos.
"""

from pathlib import Path
import subprocess

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SVG = ROOT / "design/cercly-sky/svg"
RES = ROOT / "android/app/src/main/res"
DRAWABLE = RES / "drawable-nodpi"


def render(name: str, target: Path) -> None:
    subprocess.run(
        ["magick", "-background", "none", "-density", "288",
         str(SVG / name), "-resize", "432x432", str(target)],
        check=True,
        capture_output=True,
        text=True,
    )


def main() -> None:
    DRAWABLE.mkdir(parents=True, exist_ok=True)
    for environment in ("amanecer", "dia", "atardecer", "noche"):
        render(f"icono-{environment}.svg", DRAWABLE / f"cercly_sky_icon_{environment}.png")
        render(
            f"adaptativo-frente-{environment}.svg",
            DRAWABLE / f"cercly_sky_foreground_{environment}.png",
        )
        render(
            f"adaptativo-fondo-{environment}.svg",
            DRAWABLE / f"cercly_sky_background_{environment}.png",
        )
    render("monocromo-dia.svg", DRAWABLE / "cercly_sky_monochrome.png")
    day = Image.open(DRAWABLE / "cercly_sky_icon_dia.png").convert("RGBA")
    for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                          ("xxhdpi", 144), ("xxxhdpi", 192)):
        day.resize((size, size), Image.Resampling.LANCZOS).save(
            RES / f"mipmap-{density}/ic_launcher.png"
        )
    (RES / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@drawable/cercly_sky_background_dia" />\n'
        '    <foreground android:drawable="@drawable/cercly_sky_foreground_dia" />\n'
        '    <monochrome android:drawable="@drawable/cercly_sky_monochrome" />\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )
    splash = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <item android:drawable="@color/cercly_icon_background" />\n'
        '    <item android:drawable="@drawable/cercly_sky_foreground_dia" '
        'android:gravity="center" android:width="144dp" android:height="144dp" />\n'
        '</layer-list>\n'
    )
    for directory in ("drawable", "drawable-v21"):
        (RES / directory / "launch_background.xml").write_text(splash, encoding="utf-8")
    (RES / "values/cercly_icon.xml").write_text(
        '<resources>\n'
        '    <color name="cercly_icon_background">#E8F6FF</color>\n'
        '</resources>\n',
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
