"""Draw Gearwise's original small arrow icons, with a dark outline for contrast."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "Gearwise" / "Media"


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    # Draw at 4x and reduce once for an antialiased, quiet 18px overlay.
    points = [(9, 1), (17, 9), (12, 9), (12, 17), (6, 17), (6, 9), (1, 9)]
    for name, color in (("Upgrade", (55, 225, 110, 255)), ("Downgrade", (245, 80, 80, 255))):
        vertices = points if name == "Upgrade" else [(x, 18 - y) for x, y in points]
        image = Image.new("RGBA", (72, 72))
        draw = ImageDraw.Draw(image)
        scaled = [(x * 4, y * 4) for x, y in vertices]
        draw.polygon(scaled, fill=color)
        draw.line(scaled + [scaled[0]], fill=(12, 18, 23, 255), width=5, joint="curve")
        # WoW's loose TGA loader needs power-of-two texture dimensions.
        image.resize((32, 32), Image.Resampling.LANCZOS).save(DEST / f"{name}.tga")


if __name__ == "__main__":
    main()
