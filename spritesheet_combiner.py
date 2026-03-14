import os, math, sys
from datetime import datetime
from PIL import Image

IN_DIR = "spritesheetcombiner_in"
OUT_DIR = "spritesheetcombiner_out"

EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".webp"}

def combine():
    files = sorted(
        f for f in os.listdir(IN_DIR)
        if os.path.splitext(f)[1].lower() in EXTS and not f.endswith(".import")
    )
    if not files:
        print("No images found in", IN_DIR)
        return

    imgs = [Image.open(os.path.join(IN_DIR, f)).convert("RGBA") for f in files]
    w, h = imgs[0].size
    n = len(imgs)

    cols = math.ceil(math.sqrt(n))
    rows = math.ceil(n / cols)

    sheet = Image.new("RGBA", (cols * w, rows * h), (0, 0, 0, 0))
    for i, img in enumerate(imgs):
        x = (i % cols) * w
        y = (i // cols) * h
        sheet.paste(img, (x, y))

    os.makedirs(OUT_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = os.path.join(OUT_DIR, f"spritesheet_{timestamp}.png")
    sheet.save(out_path)
    print(f"Saved {cols}x{rows} sheet ({cols*w}x{rows*h}px, {n} frames) -> {out_path}")

if __name__ == "__main__":
    combine()
