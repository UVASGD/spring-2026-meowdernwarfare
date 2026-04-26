import argparse
import os
import sys
import traceback

try:
    from PIL import Image, ImageChops
except ModuleNotFoundError:
    print("Pillow (PIL) is not installed in this interpreter.")
    print("Python:", sys.executable)
    print("Install with: python -m pip install pillow")
    sys.exit(1)


EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".webp", ".tif", ".tiff"}


def _image_paths(folder: str, recursive: bool):
    if recursive:
        for root, _, files in os.walk(folder):
            for name in sorted(files):
                ext = os.path.splitext(name)[1].lower()
                if ext in EXTS and not name.endswith(".import"):
                    yield os.path.join(root, name)
    else:
        for name in sorted(os.listdir(folder)):
            path = os.path.join(folder, name)
            ext = os.path.splitext(name)[1].lower()
            if os.path.isfile(path) and ext in EXTS and not name.endswith(".import"):
                yield path


def _alpha_bbox(img: Image.Image, threshold: int):
    alpha = img.convert("RGBA").getchannel("A")
    if threshold <= 0:
        return alpha.getbbox()
    mask = alpha.point(lambda a: 255 if a > threshold else 0)
    return mask.getbbox()


def _edge_bbox(img: Image.Image, threshold: int):
    rgba = img.convert("RGBA")
    bg = Image.new("RGBA", rgba.size, rgba.getpixel((0, 0)))
    diff = ImageChops.difference(rgba, bg).convert("L")
    mask = diff.point(lambda v: 255 if v > threshold else 0)
    return mask.getbbox()


def _trim(path: str, out_path: str, mode: str, threshold: int, pad: int):
    with Image.open(path) as im:
        bbox = _alpha_bbox(im, threshold) if mode == "alpha" else _edge_bbox(im, threshold)
        if not bbox:
            print(f"Skipped empty image: {path}")
            return False

        left, top, right, bottom = bbox
        left = max(0, left - pad)
        top = max(0, top - pad)
        right = min(im.width, right + pad)
        bottom = min(im.height, bottom + pad)

        if (left, top, right, bottom) == (0, 0, im.width, im.height):
            print(f"No trim needed: {path}")
            return False

        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        im.crop((left, top, right, bottom)).save(out_path)
        print(f"Trimmed {path} -> {out_path} ({im.width}x{im.height} to {right-left}x{bottom-top})")
        return True


def trim_folder(folder: str, output: str | None, mode: str, threshold: int, pad: int, recursive: bool):
    if not os.path.isdir(folder):
        print("Folder not found:", folder)
        return 1

    paths = list(_image_paths(folder, recursive))
    if not paths:
        print("No images found in", folder)
        return 1

    changed = 0
    for path in paths:
        if output:
            rel = os.path.relpath(path, folder)
            out_path = os.path.join(output, rel)
        else:
            out_path = path

        try:
            if _trim(path, out_path, mode, threshold, pad):
                changed += 1
        except Exception as e:
            print(f"Skipping {path}: {e}")

    print(f"Done. Trimmed {changed}/{len(paths)} images.")
    return 0


if __name__ == "__main__":
    try:
        ap = argparse.ArgumentParser(description="Trim images to the smallest content bounding box.")
        ap.add_argument("folder", help="folder containing images to trim")
        ap.add_argument("-o", "--output", default=None,
                        help="output folder. If omitted, files are overwritten in place")
        ap.add_argument("-m", "--mode", choices=("alpha", "edge"), default="alpha",
                        help="alpha trims transparent borders; edge trims borders matching the top-left pixel")
        ap.add_argument("-t", "--threshold", type=int, default=0,
                        help="ignore alpha/difference values at or below this value")
        ap.add_argument("-p", "--pad", type=int, default=0,
                        help="pixels of padding to keep around the bounding box")
        ap.add_argument("-r", "--recursive", action="store_true",
                        help="include images in subfolders")
        args = ap.parse_args()

        sys.exit(trim_folder(args.folder, args.output, args.mode, args.threshold, args.pad, args.recursive))
    except Exception:
        print("Image trim failed:")
        traceback.print_exc()
        sys.exit(1)
