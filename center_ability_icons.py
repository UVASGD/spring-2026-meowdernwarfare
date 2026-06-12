import argparse
import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ModuleNotFoundError:
    print("Pillow (PIL) is not installed in this interpreter.")
    print("Python:", sys.executable)
    print("Install with: python -m pip install pillow")
    sys.exit(1)


ROOT = Path(__file__).resolve().parent
SRC_DIR = ROOT / "ability_icons_pre_centering"
OUT_DIR = ROOT / "ability_icons_centered"


def parse_size(raw: str) -> tuple[int, int]:
    raw = raw.lower().replace(" ", "")
    if "x" not in raw:
        raise ValueError("size must look like WIDTHxHEIGHT, e.g. 1024x1024")
    w_txt, h_txt = raw.split("x", 1)
    w = int(w_txt)
    h = int(h_txt)
    if w <= 0 or h <= 0:
        raise ValueError("size values must be positive")
    return w, h


def out_path(src: Path, src_root: Path, dst_root: Path) -> Path:
    rel = src.relative_to(src_root)
    return dst_root / rel


def center_icons(
    src_dir: Path,
    dst_dir: Path,
    canvas: tuple[int, int],
    fit: float,
    in_place: bool,
) -> tuple[int, int]:
    if not src_dir.is_dir():
        raise FileNotFoundError(f"Input folder not found: {src_dir}")

    pngs = sorted(
        p for p in src_dir.iterdir() if p.is_file() and p.suffix.lower() == ".png"
    )
    if not pngs:
        return 0, 0

    if not in_place:
        dst_dir.mkdir(parents=True, exist_ok=True)

    done = 0
    skipped = 0
    cw, ch = canvas
    max_w = int(cw * fit)
    max_h = int(ch * fit)
    if max_w < 1 or max_h < 1:
        raise ValueError("fit is too small for the chosen canvas")

    for src in pngs:
        with Image.open(src) as im:
            img = im.convert("RGBA")
            box = img.getbbox()
            if not box:
                skipped += 1
                continue

            cut = img.crop(box)
            w, h = cut.size
            scale = min(max_w / w, max_h / h)
            nw = max(1, int(round(w * scale)))
            nh = max(1, int(round(h * scale)))
            resized = cut.resize((nw, nh), Image.Resampling.LANCZOS)

            out = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
            x = (cw - nw) // 2
            y = (ch - nh) // 2
            out.alpha_composite(resized, (x, y))

            if in_place:
                dst = src
            else:
                dst = out_path(src, src_dir, dst_dir)
                dst.parent.mkdir(parents=True, exist_ok=True)
            out.save(dst)
            done += 1

    return done, skipped


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Center and standardize ability icons on a shared canvas."
    )
    ap.add_argument(
        "--src",
        default=str(SRC_DIR),
        help="input directory (default: ability_icons_pre_centering)",
    )
    ap.add_argument(
        "--out",
        default=str(OUT_DIR),
        help="output directory (ignored when --in-place is set)",
    )
    ap.add_argument(
        "--size",
        default="1024x1024",
        help="output canvas size, e.g. 1024x1024",
    )
    ap.add_argument(
        "--fit",
        type=float,
        default=0.74,
        help="fraction of canvas used by icon (0-1), default 0.74",
    )
    ap.add_argument(
        "--in-place",
        action="store_true",
        help="overwrite source PNGs instead of writing to --out",
    )
    args = ap.parse_args()

    if not (0 < args.fit <= 1):
        print("--fit must be > 0 and <= 1")
        return 1

    try:
        canvas = parse_size(args.size)
        done, skipped = center_icons(
            src_dir=Path(args.src).resolve(),
            dst_dir=Path(args.out).resolve(),
            canvas=canvas,
            fit=args.fit,
            in_place=args.in_place,
        )
    except Exception as e:
        print("Icon centering failed:", e)
        return 1

    if done == 0 and skipped == 0:
        print("No PNG files found.")
        return 0

    mode = "in place" if args.in_place else f"to {Path(args.out).resolve()}"
    print(
        f"Processed {done} icons ({skipped} skipped) on {canvas[0]}x{canvas[1]} canvas, fit={args.fit} {mode}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
