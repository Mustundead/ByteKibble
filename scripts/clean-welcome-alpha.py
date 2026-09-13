"""User-authorized local mask: remove only the two exterior ground-shadow tabs.

Uses the existing dark lower outline as the mask boundary. RGB and every pixel
above the lower outline remain byte-identical; original is kept separately.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
target = root / "Sources/ByteKibble/Resources/WelcomeArtwork.png"
original = root / "Resources/Installer/welcome-artwork-before-mask.png"
if not original.exists():
    original.write_bytes(target.read_bytes())
im = Image.open(original).convert("RGBA")
assert im.size == (1774, 887), "Mask calibrated to the selected source only"
pixels = im.load()
changed = 0
for x in range(im.width):
    outline = [y for y in range(520, im.height)
               if (lambda c: c[3] > 180 and c[0] < 135 and c[1] < 80 and c[2] < 45)(pixels[x, y])]
    boundary = max(outline) if outline else 600
    for y in range(max(600, boundary + 1), im.height):
        r, g, b, a = pixels[x, y]
        if a:
            pixels[x, y] = (r, g, b, 0)
            changed += 1
im.save(target)
out = root / "output/acceptance/alpha-cleanup"
out.mkdir(parents=True, exist_ok=True)
for name, color in [("dark", "#242119"), ("light", "#fff9e9")]:
    bg = Image.new("RGBA", im.size, color)
    bg.alpha_composite(im)
    bg.convert("RGB").save(out / f"welcome-{name}.png")
assert Image.open(target).getchannel("A").getextrema() == (0, 255)
print(f"Removed alpha from {changed} shadow pixels; RGB unchanged; original: {original}")
