#!/usr/bin/env python3
# Splynek logo — refined / Apple-ish pass.
#
# Design decisions for v2:
#   - Drop the three-converging-lines composition. It read as a chart,
#     not a mark, and made the icon feel diagrammatic rather than
#     brand-ish.
#   - Keep the squircle (macOS/iOS convention) but go darker + richer
#     — deep navy at the top to near-black at the bottom, similar to
#     the dusk gradient in Apple's Astronomy/Podcasts iconography.
#   - A single elegant down-arrow as the mark. Thin shaft with gently
#     tapered head. White with a subtle vertical gradient so it reads
#     as polished, not flat.
#   - A very-thin "landing" bar underneath, low-opacity, to keep the
#     download story without screaming it.
#   - Soft radial highlight at the top-left (like light catching glass)
#     and a barely-there vignette at the bottom. Same treatment as
#     Safari / Maps.
#
# Still pure stdlib (zlib + struct). No Pillow, no cairo, no deps.

import math
import struct
import zlib
import os

# ---- PNG encoder ----------------------------------------------------

def png_bytes(w, h, pixels):
    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        crc = zlib.crc32(tag + data)
        return out + struct.pack(">I", crc)
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)  # 8-bit RGBA
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for r, g, b, a in row:
            raw.extend([r, g, b, a])
    idat = zlib.compress(bytes(raw), 9)
    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")

# ---- Color helpers --------------------------------------------------

def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return (
        int(c1[0] + (c2[0] - c1[0]) * t),
        int(c1[1] + (c2[1] - c1[1]) * t),
        int(c1[2] + (c2[2] - c1[2]) * t),
        int(c1[3] + (c2[3] - c1[3]) * t),
    )

def over(dst, src):
    a = src[3] / 255
    return (
        int(src[0] * a + dst[0] * (1 - a)),
        int(src[1] * a + dst[1] * (1 - a)),
        int(src[2] * a + dst[2] * (1 - a)),
        min(255, dst[3] + int(src[3] * (1 - dst[3] / 255))),
    )

# ---- Shape helpers --------------------------------------------------

def squircle_alpha(x, y, size, softness=1.2):
    """Apple-style superellipse with 1px anti-aliased edge.
    Returns 0..1 indicating how "inside" the shape the pixel is."""
    n = 5
    cx, cy = (size - 1) / 2, (size - 1) / 2
    rx, ry = cx, cy
    nx = abs(x - cx) / rx
    ny = abs(y - cy) / ry
    d = (nx ** n + ny ** n) ** (1 / n)
    # d=1 is exactly on the boundary; softness controls AA band width
    # (expressed as a fraction of the half-size).
    band = softness / max(rx, ry)
    if d <= 1 - band:
        return 1.0
    if d >= 1 + band:
        return 0.0
    return (1 - (d - (1 - band)) / (2 * band))

def dist_to_segment(px, py, x1, y1, x2, y2):
    dx, dy = x2 - x1, y2 - y1
    length_sq = dx * dx + dy * dy
    if length_sq == 0:
        return math.hypot(px - x1, py - y1)
    t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / length_sq))
    proj_x = x1 + t * dx
    proj_y = y1 + t * dy
    return math.hypot(px - proj_x, py - proj_y)

def point_in_triangle(px, py, v1, v2, v3):
    def sign(a, b, c):
        return (a[0] - c[0]) * (b[1] - c[1]) - (b[0] - c[0]) * (a[1] - c[1])
    p = (px, py)
    d1 = sign(p, v1, v2)
    d2 = sign(p, v2, v3)
    d3 = sign(p, v3, v1)
    has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (has_neg and has_pos)

# ---- Palette --------------------------------------------------------

# Deep navy top → nearly black bottom. Pulls in a tiny hint of indigo
# so the gradient reads warm-blue rather than flat slate. Close cousin
# to the gradient on Apple Music's icon.
BG_TOP    = (28, 54, 110, 255)
BG_MID    = (14, 28, 68,  255)
BG_BOT    = (6,  10, 30,  255)

HIGHLIGHT = (255, 255, 255, 70)     # top-left radial
VIGNETTE  = (0,   0,   0,   60)     # bottom-right darkening

ARROW_TOP    = (255, 255, 255, 255)
ARROW_BOT    = (220, 230, 245, 255)  # subtle cool shift at the tip
ARROW_SHADOW = (0, 0, 0, 40)         # faint drop shadow

LANDING      = (255, 255, 255, 120)  # thin bar, ~50% opacity

TRANSPARENT  = (0, 0, 0, 0)

# ---- Drawing --------------------------------------------------------

def render(size):
    px = [[TRANSPARENT] * size for _ in range(size)]

    cx = size / 2
    cy = size / 2

    # 1. Squircle background — two-stop vertical gradient with a
    #    slight quadratic curve so the top brightens faster than
    #    the middle darkens. Feels more like light catching glass.
    for y in range(size):
        t = y / max(1, size - 1)
        if t < 0.55:
            bg = mix(BG_TOP, BG_MID, t / 0.55)
        else:
            bg = mix(BG_MID, BG_BOT, (t - 0.55) / 0.45)
        for x in range(size):
            a = squircle_alpha(x, y, size)
            if a > 0:
                col = (bg[0], bg[1], bg[2], int(255 * a))
                px[y][x] = col

    # 2. Top-left radial highlight — subtle gloss.
    hx, hy = size * 0.30, size * 0.20
    h_radius = size * 0.55
    for y in range(size):
        for x in range(size):
            if px[y][x][3] == 0:
                continue
            d = math.hypot(x - hx, y - hy)
            if d < h_radius:
                falloff = 1 - (d / h_radius) ** 1.4
                glow = (HIGHLIGHT[0], HIGHLIGHT[1], HIGHLIGHT[2],
                        int(HIGHLIGHT[3] * falloff))
                px[y][x] = over(px[y][x], glow)

    # 3. Bottom-right vignette — a whisper of depth.
    vx, vy = size * 0.75, size * 0.80
    v_radius = size * 0.55
    for y in range(size):
        for x in range(size):
            if px[y][x][3] == 0:
                continue
            d = math.hypot(x - vx, y - vy)
            if d < v_radius:
                falloff = 1 - (d / v_radius) ** 1.2
                shade = (VIGNETTE[0], VIGNETTE[1], VIGNETTE[2],
                         int(VIGNETTE[3] * falloff))
                px[y][x] = over(px[y][x], shade)

    # 4. Arrow — a single elegant down-arrow with gently tapered head.
    # Proportions chosen to feel crisp at 16px and still graceful at 1024.
    shaft_w      = size * 0.09
    shaft_top_y  = size * 0.26
    shaft_bot_y  = size * 0.58
    head_top_y   = shaft_bot_y
    head_bot_y   = size * 0.75
    head_w       = size * 0.34

    # Soft shadow pass first (1-2 px offset down).
    def draw_arrow(fill_top, fill_bot, dx=0.0, dy=0.0, shaft_gradient=True):
        # Shaft — rounded rect (approx).
        shaft_left  = cx - shaft_w / 2 + dx
        shaft_right = cx + shaft_w / 2 + dx
        for y in range(size):
            fy = y + 0.5
            if not (shaft_top_y + dy <= fy <= shaft_bot_y + dy):
                continue
            for x in range(size):
                fx = x + 0.5
                if shaft_left <= fx <= shaft_right:
                    alpha_bg = squircle_alpha(x, y, size)
                    if alpha_bg <= 0:
                        continue
                    # Rounded top-left / top-right of the shaft for polish.
                    corner_r = shaft_w * 0.35
                    top_r = shaft_top_y + dy + corner_r
                    local_corner_alpha = 1.0
                    if fy < top_r:
                        cx_l = shaft_left + corner_r
                        cx_r = shaft_right - corner_r
                        cy_top = top_r
                        if fx < cx_l:
                            d = math.hypot(fx - cx_l, fy - cy_top)
                            local_corner_alpha = max(0, min(1, (corner_r - d) + 0.5))
                        elif fx > cx_r:
                            d = math.hypot(fx - cx_r, fy - cy_top)
                            local_corner_alpha = max(0, min(1, (corner_r - d) + 0.5))
                    if local_corner_alpha <= 0:
                        continue
                    # Shaft colour: subtle top-to-bottom mix.
                    if shaft_gradient:
                        t = (fy - (shaft_top_y + dy)) / max(1, (shaft_bot_y - shaft_top_y))
                        col = mix(fill_top, fill_bot, t)
                    else:
                        col = fill_top
                    px[y][x] = over(px[y][x], (col[0], col[1], col[2],
                                               int(col[3] * local_corner_alpha)))

        # Head — filled triangle.
        v1 = (cx - head_w / 2 + dx, head_top_y + dy)
        v2 = (cx + head_w / 2 + dx, head_top_y + dy)
        v3 = (cx + dx, head_bot_y + dy)
        for y in range(size):
            fy = y + 0.5
            if not (head_top_y + dy - 1 <= fy <= head_bot_y + dy + 1):
                continue
            for x in range(size):
                fx = x + 0.5
                if point_in_triangle(fx, fy, v1, v2, v3):
                    alpha_bg = squircle_alpha(x, y, size)
                    if alpha_bg <= 0:
                        continue
                    if shaft_gradient:
                        t = (fy - (head_top_y + dy)) / max(1, head_bot_y - head_top_y)
                        col = mix(fill_top, fill_bot, min(1.0, 0.5 + t * 0.5))
                    else:
                        col = fill_top
                    px[y][x] = over(px[y][x], col)

    # Shadow first (offset down-right, very faint).
    draw_arrow(ARROW_SHADOW, ARROW_SHADOW,
               dx=size * 0.004, dy=size * 0.010,
               shaft_gradient=False)
    # Arrow proper.
    draw_arrow(ARROW_TOP, ARROW_BOT)

    # 5. Landing bar — thin, low-opacity, anchored below the arrow.
    bar_w      = size * 0.30
    bar_h      = max(1.2, size * 0.028)
    bar_y      = head_bot_y + size * 0.06
    bar_left   = cx - bar_w / 2
    bar_right  = cx + bar_w / 2
    bar_radius = bar_h / 2
    for y in range(size):
        fy = y + 0.5
        if not (bar_y <= fy <= bar_y + bar_h):
            continue
        for x in range(size):
            fx = x + 0.5
            if bar_left <= fx <= bar_right:
                alpha_bg = squircle_alpha(x, y, size)
                if alpha_bg <= 0:
                    continue
                # Round the ends.
                cr = bar_radius
                corner_alpha = 1.0
                if fx < bar_left + cr:
                    d = math.hypot(fx - (bar_left + cr), fy - (bar_y + cr))
                    if d > cr:
                        corner_alpha = max(0, 1 - (d - cr))
                elif fx > bar_right - cr:
                    d = math.hypot(fx - (bar_right - cr), fy - (bar_y + cr))
                    if d > cr:
                        corner_alpha = max(0, 1 - (d - cr))
                if corner_alpha > 0:
                    col = (LANDING[0], LANDING[1], LANDING[2],
                           int(LANDING[3] * corner_alpha))
                    px[y][x] = over(px[y][x], col)

    return px

# ---- Outputs --------------------------------------------------------

ICONSET_PAIRS = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",     128),
    ("icon_128x128@2x.png",  256),
    ("icon_256x256.png",     256),
    ("icon_256x256@2x.png",  512),
    ("icon_512x512.png",     512),
    ("icon_512x512@2x.png",  1024),
]

FLAT_SIZES = (16, 32, 48, 64, 128, 256, 512, 1024)

def write_png(path, size):
    pixels = render(size)
    with open(path, "wb") as f:
        f.write(png_bytes(size, size, pixels))
    print(f"wrote {os.path.basename(path)} ({size}x{size})")

if __name__ == "__main__":
    base = os.path.dirname(os.path.abspath(__file__))
    iconset = os.path.join(base, "icon.iconset")
    os.makedirs(iconset, exist_ok=True)
    for name, size in ICONSET_PAIRS:
        write_png(os.path.join(iconset, name), size)
    flat = os.path.join(base, "flat")
    os.makedirs(flat, exist_ok=True)
    for size in FLAT_SIZES:
        write_png(os.path.join(flat, f"icon-{size}.png"), size)
    print("Done.")
