import io, os, math, sys, traceback, argparse
from datetime import datetime
try:
    from PIL import Image
except ModuleNotFoundError:
    print("Pillow (PIL) is not installed in this interpreter.")
    print("Python:", sys.executable)
    print("Install with: python -m pip install pillow")
    sys.exit(1)

def _rembg_remove(img: Image.Image) -> Image.Image:
    from rembg import remove as rembg_remove
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    out = rembg_remove(buf.getvalue())
    return Image.open(io.BytesIO(out)).convert("RGBA")

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
IN_DIR = os.path.join(ROOT_DIR, "spritesheetcombiner_in")
OUT_DIR = os.path.join(ROOT_DIR, "spritesheetcombiner_out")

EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".webp", ".tif", ".tiff"}

def _safe_name(s: str) -> str:
    out = []
    last_was_sep = False
    for ch in s.strip().lower():
        if ch.isalnum():
            out.append(ch)
            last_was_sep = False
        else:
            if not last_was_sep:
                out.append("_")
                last_was_sep = True
    return "".join(out).strip("_")

def _white_to_alpha(img: Image.Image, cutoff: int = 245) -> Image.Image:
    px = img.getdata()
    out = []
    for r, g, b, a in px:
        if r >= cutoff and g >= cutoff and b >= cutoff:
            out.append((r, g, b, 0))
        else:
            out.append((r, g, b, a))
    img.putdata(out)
    return img

def _edge_bg_to_alpha(img: Image.Image, tolerance: int = 15) -> Image.Image:
    w, h = img.size
    px = img.load()
    border = []
    for x in range(w):
        border.append((x, 0))
        if h > 1:
            border.append((x, h - 1))
    for y in range(1, h - 1):
        border.append((0, y))
        if w > 1:
            border.append((w - 1, y))
    if not border:
        return img
    r_sum, g_sum, b_sum, n = 0, 0, 0, 0
    for (x, y) in border:
        p = px[x, y]
        if len(p) == 4 and p[3] < 128:
            continue
        r_sum += p[0]
        g_sum += p[1]
        b_sum += p[2]
        n += 1
    if n == 0:
        return img
    br, bg, bb = r_sum // n, g_sum // n, b_sum // n

    def match(c):
        return (abs(c[0] - br) <= tolerance and
                abs(c[1] - bg) <= tolerance and
                abs(c[2] - bb) <= tolerance and
                (len(c) == 3 or c[3] > 128))

    seen = set()
    stack = [(x, y) for (x, y) in border if match(px[x, y])]
    for (x, y) in stack:
        seen.add((x, y))
    while stack:
        x, y = stack.pop()
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and match(px[nx, ny]):
                seen.add((nx, ny))
                stack.append((nx, ny))
    for (x, y) in seen:
        p = list(px[x, y])
        if len(p) == 4:
            p[3] = 0
            px[x, y] = tuple(p)
    return img

def _image_names(folder: str):
    return sorted(
        f for f in os.listdir(folder)
        if os.path.splitext(f)[1].lower() in EXTS and not f.endswith(".import")
    )

def _image_dirs(root: str):
    out = []
    for dirpath, _, _ in os.walk(root):
        if _image_names(dirpath):
            out.append(dirpath)
    return sorted(out)

def _sheet_name(src_dir: str, used: set[str]) -> str:
    rel = os.path.relpath(src_dir, IN_DIR)
    parts = [] if rel == "." else rel.split(os.sep)
    if len(parts) > 1:
        parts = parts[1:]
    name = "_".join(_safe_name(p) for p in parts if _safe_name(p))
    if not name:
        name = datetime.now().strftime("spritesheet_%Y%m%d_%H%M%S")

    base = name
    i = 2
    while f"{name}.png" in used:
        name = f"{base}_{i}"
        i += 1
    used.add(f"{name}.png")
    return f"{name}.png"

def _resolve_output_path(output: str | None, fallback_name: str) -> str:
    if not output:
        return os.path.join(OUT_DIR, fallback_name)
    out = output.strip()
    if not out:
        return os.path.join(OUT_DIR, fallback_name)
    if not os.path.splitext(out)[1]:
        out += ".png"
    if os.path.isabs(out):
        return out
    if os.path.dirname(out):
        return os.path.join(ROOT_DIR, out)
    return os.path.join(OUT_DIR, out)

def _make_sheet(src_dir: str, out_path: str, remove_white: bool, smart_bg: bool, use_rembg: bool):
    files = _image_names(src_dir)
    if not files:
        return False

    imgs = []
    used_files = []
    for f in files:
        p = os.path.join(src_dir, f)
        try:
            with Image.open(p) as im:
                img = im.convert("RGBA")
                if use_rembg:
                    img = _rembg_remove(img)
                elif smart_bg:
                    img = _edge_bg_to_alpha(img)
                elif remove_white:
                    img = _white_to_alpha(img)
                imgs.append(img)
                used_files.append(f)
        except Exception as e:
            print(f"Skipping {p}: {e}")

    if not imgs:
        return False

    w, h = imgs[0].size
    n = len(used_files)
    cols = math.ceil(math.sqrt(n))
    rows = math.ceil(n / cols)

    sheet = Image.new("RGBA", (cols * w, rows * h), (0, 0, 0, 0))
    for i, img in enumerate(imgs):
        x = (i % cols) * w
        y = (i // cols) * h
        sheet.paste(img, (x, y))

    sheet.save(out_path)
    print(f"Saved {cols}x{rows} sheet ({cols*w}x{rows*h}px, {n} frames) -> {out_path}")
    return True

def combine(remove_white: bool = False, smart_bg: bool = False, use_rembg: bool = False, output: str | None = None):
    if not os.path.isdir(IN_DIR):
        print("Input folder not found:", IN_DIR)
        return

    os.makedirs(OUT_DIR, exist_ok=True)
    dirs = _image_dirs(IN_DIR)

    if len(dirs) > 1 or (dirs and dirs[0] != IN_DIR):
        used_names = set()
        made_any = False
        for src_dir in dirs:
            out_path = os.path.join(OUT_DIR, _sheet_name(src_dir, used_names))
            if _make_sheet(src_dir, out_path, remove_white, smart_bg, use_rembg):
                made_any = True
        if output and made_any:
            print("Note: --output is ignored when combining multiple folders.")
        if not made_any:
            print("No images found in", IN_DIR)
        return

    files = _image_names(IN_DIR)
    if not files:
        print("No images found in", IN_DIR)
        return

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = _resolve_output_path(output, f"spritesheet_{timestamp}.png")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    _make_sheet(IN_DIR, out_path, remove_white, smart_bg, use_rembg)

if __name__ == "__main__":
    try:
        ap = argparse.ArgumentParser()
        ap.add_argument("-t", action="store_true", help="simple white->transparent (all near-white)")
        ap.add_argument("-a", action="store_true", help="legacy alias for -t")
        ap.add_argument("-T", "--smart-bg", action="store_true",
                        help="remove only edge-connected background (keeps white details)")
        ap.add_argument("-r", "--rembg", action="store_true",
                        help="AI background removal (pip install rembg)")
        ap.add_argument("-o", "--output", default=None,
                        help="output name or path (default: timestamped name in spritesheetcombiner_out)")
        args = ap.parse_args()
        if args.rembg:
            try:
                import rembg
            except ModuleNotFoundError:
                print("rembg is not installed.")
                print("Install with: python -m pip install rembg")
                sys.exit(1)
        combine(remove_white=(args.t or args.a), smart_bg=args.smart_bg, use_rembg=args.rembg, output=args.output)
    except Exception:
        print("Spritesheet combine failed:")
        traceback.print_exc()
        sys.exit(1)
