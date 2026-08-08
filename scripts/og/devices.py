#!/usr/bin/env python3
"""
GitHub social-preview (Open Graph) image for thechrisgrey/sleep-token-kb.

Direction: DEVICE SHOWCASE.
Three real app captures fanned across the right two-thirds of the canvas, tilted,
overlapping, bleeding off the bottom and right edges. A rose radial bloom and
deterministic falling petals sit behind them; compact typography holds the left
column. Everything is drawn at 3x and LANCZOS-downscaled to 1280x640.

Pure Python 3 + Pillow. No network, no external assets beyond repo files.
"""

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

# ----------------------------------------------------------------------------
# paths
# ----------------------------------------------------------------------------
ROOT = "/Users/cperez/dev/delta-centric-dev/sleep-token-kb"
SHOTS = os.path.join(ROOT, "docs", "screenshots")
OUT = os.path.join(ROOT, "docs", "og-devices.png")
OUT_THUMB = "/private/tmp/claude-501/-Users-cperez-dev-altivum-dev-sleep-token-kb/09ba2e3c-f49f-4058-963f-42064224b8e8/scratchpad/og-devices-500.png"

F_NEWYORK = "/System/Library/Fonts/NewYork.ttf"
F_NEWYORK_IT = "/System/Library/Fonts/NewYorkItalic.ttf"
F_SFNS = "/System/Library/Fonts/SFNS.ttf"
F_RUNES = os.path.join(ROOT, "SleepTokenKB", "SleepTokenRunes.ttf")

# ----------------------------------------------------------------------------
# canvas / palette
# ----------------------------------------------------------------------------
W, H = 1280, 640
S = 3                       # supersample factor
CW, CH = W * S, H * S

FIELD = (10, 14, 12)
SURFACE = (19, 29, 23)
SURFACE_HIGH = (28, 42, 34)
INK = (237, 230, 209)
INK_DIM = (163, 166, 148)
ROSE = (222, 148, 171)
ROSE_DEEP = (168, 92, 117)
CHAMPAGNE = (199, 181, 122)
GOLD = (204, 171, 102)


def px(v):
    """1x design units -> supersampled device pixels."""
    return int(round(v * S))


def rune(s):
    return "".join(chr(0xE900 + (ord(c) - 97)) for c in s.lower() if c.isalpha())


def font(path, size_1x, variation=None):
    f = ImageFont.truetype(path, px(size_1x))
    if variation:
        try:
            f.set_variation_by_name(variation)
        except Exception:
            pass
    return f


def mix(c1, c2, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c1, c2))


def rgba(c, a):
    return (c[0], c[1], c[2], int(round(a)))


# ----------------------------------------------------------------------------
# compositing helpers
# ----------------------------------------------------------------------------
def blit(base, tile, x, y):
    """alpha_composite `tile` onto `base` at (x, y), cropping to canvas."""
    bw, bh = base.size
    tw, th = tile.size
    sx = max(0, -x)
    sy = max(0, -y)
    ex = min(tw, bw - x)
    ey = min(th, bh - y)
    if ex <= sx or ey <= sy:
        return
    if (sx, sy, ex, ey) != (0, 0, tw, th):
        tile = tile.crop((sx, sy, ex, ey))
    base.alpha_composite(tile, dest=(x + sx, y + sy))


_RADIAL_CACHE = {}


def radial_mask(n, power):
    """Square 'L' falloff mask, 255 at centre -> 0 at the inscribed circle."""
    key = (n, round(power, 3))
    if key in _RADIAL_CACHE:
        return _RADIAL_CACHE[key]
    half = (n - 1) / 2.0
    data = []
    for j in range(n):
        dy = (j - half) / half
        dy2 = dy * dy
        for i in range(n):
            dx = (i - half) / half
            d = math.sqrt(dx * dx + dy2)
            v = 1.0 - d
            data.append(int(255 * (v ** power)) if v > 0 else 0)
    img = Image.new("L", (n, n))
    img.putdata(data)
    _RADIAL_CACHE[key] = img
    return img


def bloom(base, cx, cy, rx, ry, color, peak, power=2.2):
    """Soft elliptical radial glow, additively soft on top of the field."""
    m = radial_mask(160, power).resize((max(2, px(rx * 2)), max(2, px(ry * 2))),
                                       Image.Resampling.BICUBIC)
    if peak < 255:
        m = m.point(lambda v: int(v * peak / 255.0))
    tile = Image.new("RGBA", m.size, color + (0,))
    tile.putalpha(m)
    blit(base, tile, px(cx) - m.size[0] // 2, px(cy) - m.size[1] // 2)


def rounded_mask(size, radius, ss=3):
    w, h = size
    m = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, w * ss - 1, h * ss - 1], radius=radius * ss, fill=255)
    return m.resize((w, h), Image.Resampling.LANCZOS)


# ----------------------------------------------------------------------------
# type helpers
# ----------------------------------------------------------------------------
def tracked_width(draw, text, fnt, tracking):
    if not text:
        return 0.0
    total = 0.0
    for ch in text:
        total += draw.textlength(ch, font=fnt) + tracking
    return total - tracking


def draw_tracked(draw, x, y, text, fnt, fill, tracking=0.0, anchor="ls"):
    """Baseline-anchored, manually letter-spaced run. Returns end x."""
    cx = float(x)
    for ch in text:
        if ch != " ":
            draw.text((cx, y), ch, font=fnt, fill=fill, anchor=anchor)
        cx += draw.textlength(ch, font=fnt) + tracking
    return cx - tracking


def fit_font(draw, text, path, target_w, max_size, variation=None):
    lo, hi = 8.0, float(max_size)
    best = ImageFont.truetype(path, px(max_size))
    for _ in range(28):
        mid = (lo + hi) / 2
        f = font(path, mid, variation)
        w = draw.textlength(text, font=f)
        if w <= target_w:
            best = f
            lo = mid
        else:
            hi = mid
    return best


# ----------------------------------------------------------------------------
# petals (deterministic)
# ----------------------------------------------------------------------------
def hash01(i, salt):
    x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
    return x - math.floor(x)


def quad(p0, p1, p2, n=26):
    pts = []
    for k in range(n + 1):
        t = k / n
        u = 1 - t
        pts.append((u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                    u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]))
    return pts


def petal_polygon(w, h, angle_deg, cx, cy):
    pts = quad((0.5 * w, h), (1.08 * w, 0.42 * h), (0.5 * w, 0))
    pts += quad((0.5 * w, 0), (-0.02 * w, 0.55 * h), (0.5 * w, h))[1:]
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    ox, oy = 0.5 * w, 0.5 * h
    out = []
    for x, y in pts:
        dx, dy = x - ox, y - oy
        out.append((cx + dx * ca - dy * sa, cy + dx * sa + dy * ca))
    return out


def petal_layer(size, specs, blur):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for (cx, cy, w, h, ang, color, alpha) in specs:
        d.polygon(petal_polygon(w, h, ang, cx, cy), fill=rgba(color, alpha))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return layer


def make_petals(count, salt, bounds, size_range, alpha_range):
    x0, y0, x1, y1 = bounds
    specs = []
    for i in range(count):
        rx = hash01(i, salt)
        ry = hash01(i, salt + 3.1)
        rs = hash01(i, salt + 7.7)
        ra = hash01(i, salt + 11.3)
        rc = hash01(i, salt + 17.9)
        w = size_range[0] + (size_range[1] - size_range[0]) * (rs ** 1.7)
        h = w * (1.55 + 0.5 * hash01(i, salt + 23.5))
        color = mix(ROSE_DEEP, (243, 214, 220), rc ** 0.7)
        alpha = alpha_range[0] + (alpha_range[1] - alpha_range[0]) * ra
        specs.append((px(x0 + (x1 - x0) * rx), px(y0 + (y1 - y0) * ry),
                      px(w), px(h), 360 * hash01(i, salt + 31.1), color, alpha))
    return specs


# ----------------------------------------------------------------------------
# device rendering
# ----------------------------------------------------------------------------
def load_shot(name, splice=None):
    """Open a screenshot copy; optionally splice out a band of flat dead rows."""
    im = Image.open(os.path.join(SHOTS, name)).convert("RGB")
    if splice:
        y0, y1 = splice
        w, h = im.size
        out = Image.new("RGB", (w, h - (y1 - y0)))
        out.paste(im.crop((0, 0, w, y0)), (0, 0))
        out.paste(im.crop((0, y1, w, h)), (0, y0))
        im = out
    return im


def make_device(shot, width_1x, angle, focal=True, dim=0.0, veil=0.0, soften=0.0,
                lift=0.0, sat=1.0, bright=1.0):
    """Rounded-corner phone with bezel, hairline border; rotated, RGBA."""
    w = px(width_1x)
    h = int(round(w * shot.height / shot.width))
    shot = shot.resize((w, h), Image.Resampling.LANCZOS)

    if sat != 1.0:
        shot = ImageEnhance.Color(shot).enhance(sat)
    if bright != 1.0:
        shot = ImageEnhance.Brightness(shot).enhance(bright)
    if lift:
        shot = Image.blend(shot, Image.new("RGB", shot.size, INK), lift)
    if dim:
        shot = Image.blend(shot, Image.new("RGB", shot.size, (6, 9, 8)), dim)
    if veil:
        shot = Image.blend(shot, Image.new("RGB", shot.size, SURFACE), veil)

    bez = max(2, px(width_1x * 0.021))
    dw, dh = w + 2 * bez, h + 2 * bez
    r_out = px(width_1x * 0.118)
    r_in = max(2, r_out - bez)

    device = Image.new("RGBA", (dw, dh), (0, 0, 0, 0))
    body = Image.new("RGBA", (dw, dh), (0, 0, 0, 0))
    bmask = rounded_mask((dw, dh), r_out)
    body.paste(Image.new("RGB", (dw, dh), (7, 9, 9)), (0, 0))
    body.putalpha(bmask)
    device.alpha_composite(body)

    screen = Image.new("RGBA", shot.size)
    screen.paste(shot)
    screen.putalpha(rounded_mask((w, h), r_in))
    device.alpha_composite(screen, dest=(bez, bez))

    # hairline edge light on the bezel
    edge = Image.new("RGBA", (dw * 2, dh * 2), (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    lw = max(2, px(1.15)) * 2
    edge_col = mix(INK, ROSE, 0.32) if focal else INK
    ed.rounded_rectangle([lw // 2, lw // 2, dw * 2 - 1 - lw // 2, dh * 2 - 1 - lw // 2],
                         radius=r_out * 2, outline=rgba(edge_col, 118 if focal else 62),
                         width=lw)
    edge = edge.resize((dw, dh), Image.Resampling.LANCZOS)
    device.alpha_composite(edge)

    if soften:
        device = device.filter(ImageFilter.GaussianBlur(soften * S))

    return device.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)


def drop_shadow(base, dev, x, y, blur_1x, dx_1x, dy_1x, alpha, color=(0, 0, 0)):
    b = px(blur_1x)
    pad = int(b * 2.4) + 4
    tile = Image.new("RGBA", (dev.size[0] + 2 * pad, dev.size[1] + 2 * pad), (0, 0, 0, 0))
    silhouette = Image.new("RGBA", dev.size, color + (0,))
    a = dev.split()[3].point(lambda v: int(v * alpha))
    silhouette.putalpha(a)
    tile.paste(silhouette, (pad, pad))
    tile = tile.filter(ImageFilter.GaussianBlur(b))
    blit(base, tile, x - pad + px(dx_1x), y - pad + px(dy_1x))


def place(base, dev, cx_1x, cy_1x, shadows):
    x = px(cx_1x) - dev.size[0] // 2
    y = px(cy_1x) - dev.size[1] // 2
    for sh in shadows:
        drop_shadow(base, dev, x, y, *sh)
    blit(base, dev, x, y)
    return x, y


# ----------------------------------------------------------------------------
# build
# ----------------------------------------------------------------------------
def build():
    canvas = Image.new("RGBA", (CW, CH), FIELD + (255,))

    # --- base vertical gradient -------------------------------------------
    grad = Image.new("L", (1, 256))
    grad.putdata([int(255 * (1 - (j / 255.0) ** 0.85) * 0.85) for j in range(256)])
    g = Image.new("RGBA", (CW, CH), (18, 26, 22, 0))
    g.putalpha(grad.resize((CW, CH), Image.Resampling.BICUBIC))
    canvas.alpha_composite(g)

    # --- blooms ------------------------------------------------------------
    # the big rose stage light behind the fan
    bloom(canvas, 855, 285, 760, 580, ROSE_DEEP, 190, power=1.9)
    bloom(canvas, 875, 230, 400, 330, ROSE, 155, power=2.2)
    bloom(canvas, 885, 200, 190, 160, mix(ROSE, INK, 0.42), 120, power=2.0)
    # gold answer, kept low and mostly behind the ritual phone
    bloom(canvas, 636, 360, 300, 300, GOLD, 54, power=2.6)
    # warm floor under the type column so the left reads as space, not a hole
    bloom(canvas, 130, 452, 500, 430, ROSE_DEEP, 90, power=2.1)
    bloom(canvas, 300, 620, 380, 260, ROSE_DEEP, 52, power=2.3)
    bloom(canvas, 1215, 575, 400, 330, ROSE, 74, power=2.2)

    # --- petals behind the devices ----------------------------------------
    back = make_petals(34, 4.0, (-30, -40, 1310, 660), (9, 30), (40, 130))
    canvas.alpha_composite(petal_layer((CW, CH), back, blur=1.2 * S))

    # --- ground shadow for the whole fan ----------------------------------
    stage = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    m = radial_mask(160, 1.7).resize((px(980), px(520)), Image.Resampling.BICUBIC)
    t = Image.new("RGBA", m.size, (0, 0, 0, 0))
    t.putalpha(m.point(lambda v: int(v * 0.46)))
    blit(stage, t, px(890) - m.size[0] // 2, px(600) - m.size[1] // 2)
    canvas.alpha_composite(stage)

    # --- devices -----------------------------------------------------------
    # back left: ritual / gold alphabet grid
    dev_l = make_device(load_shot("alphabet-ritual.png"), 300, -11.0,
                        focal=False, dim=0.04, veil=0.02, soften=0.38, lift=0.05,
                        sat=1.58, bright=1.21)
    place(canvas, dev_l, 660, 486,
          shadows=[(56, -8, 26, 0.55), (17, -4, 8, 0.55)])

    # back right: arcadia / pink alphabet grid -- same screen, other theme
    dev_r = make_device(load_shot("alphabet-arcadia.png"), 306, 10.0,
                        focal=False, dim=0.03, veil=0.02, soften=0.38, lift=0.055,
                        sat=1.38, bright=1.20)
    place(canvas, dev_r, 1150, 490,
          shadows=[(56, 8, 26, 0.55), (17, 4, 8, 0.55)])

    # focal: arcadia / pink Rune Pad
    dev_c = make_device(load_shot("runepad-arcadia.png", splice=(458, 528)),
                        380, -3.0, focal=True, lift=0.05, sat=1.26, bright=1.13)
    place(canvas, dev_c, 875, 434,
          shadows=[(74, 0, 36, 0.66), (26, 0, 13, 0.60), (8, 0, 3, 0.52)])

    # --- petals in front (soft, out of focus) ------------------------------
    # a few are placed by hand so foreground petals cross the hero screen's
    # quiet canvas -- depth, and it stops that area reading as a flat hole.
    hand = [(946, 232, 34, 58, 24, mix(ROSE, (243, 214, 220), 0.30), 52),
            (1004, 402, 46, 76, 302, mix(ROSE_DEEP, ROSE, 0.55), 44),
            (890, 470, 27, 44, 118, mix(ROSE, (243, 214, 220), 0.60), 40),
            (1042, 300, 22, 36, 200, mix(ROSE_DEEP, ROSE, 0.35), 34),
            (322, 556, 42, 70, 340, mix(ROSE_DEEP, ROSE, 0.40), 32)]
    front = make_petals(10, 91.0, (340, 40, 1260, 620), (26, 54), (24, 54))
    front += [(px(x), px(y), px(w), px(h), a, c, al) for
              (x, y, w, h, a, c, al) in hand]
    canvas.alpha_composite(petal_layer((CW, CH), front, blur=3.2 * S))

    # --- vignette ----------------------------------------------------------
    vm = radial_mask(200, 0.85).resize((int(CW * 1.16), int(CH * 1.16)),
                                       Image.Resampling.BICUBIC)
    vm = vm.crop((int(CW * 0.08), int(CH * 0.08),
                  int(CW * 0.08) + CW, int(CH * 0.08) + CH))
    vign = Image.new("RGBA", (CW, CH), (4, 6, 6, 0))
    vign.putalpha(vm.point(lambda v: int((255 - v) * 0.50)))
    canvas.alpha_composite(vign)

    # extra hush on the top-left so the rose wash never reaches the corner
    cm = radial_mask(140, 1.5).resize((px(1000), px(760)), Image.Resampling.BICUBIC)
    corner = Image.new("RGBA", cm.size, (5, 8, 7, 0))
    corner.putalpha(cm.point(lambda v: int(v * 0.36)))
    blit(canvas, corner, px(-330), px(-500))

    # ------------------------------------------------------------------
    # typography
    # ------------------------------------------------------------------
    d = ImageDraw.Draw(canvas)
    X = 76
    COL_W = px(378)

    f_eyebrow = font(F_SFNS, 11.0, "Semibold")
    f_desc = font(F_SFNS, 12.6, "Medium")
    f_stat = font(F_SFNS, 10.6, "Medium")
    f_url = font(F_SFNS, 11.0, "Regular")
    f_rune = font(F_RUNES, 22.5)

    # eyebrow
    draw_tracked(d, px(X), px(214), "UNOFFICIAL FAN KEYBOARD", f_eyebrow,
                 rgba(ROSE, 235), tracking=px(3.5))

    # wordmark
    f_word = fit_font(d, "Ceremonial Scripts", F_NEWYORK, COL_W, 60.0, "Semibold")
    d.text((px(X) - px(1.5), px(276)), "Ceremonial Scripts", font=f_word,
           fill=INK + (255,), anchor="ls")

    # rune ornament: s l e e p t o k e n  (with a word gap)
    rx = float(px(X))
    ry = px(320)
    word_gap = px(11)
    for idx, ch in enumerate(rune("sleep") + " " + rune("token")):
        if ch == " ":
            rx += word_gap
            continue
        col = mix(ROSE, INK, 0.25) if idx % 3 == 0 else mix(ROSE_DEEP, INK, 0.45)
        d.text((rx, ry), ch, font=f_rune, fill=rgba(col, 228), anchor="ls")
        rx += d.textlength(ch, font=f_rune) + px(9.0)

    # descriptor
    draw_tracked(d, px(X), px(372), "THE RITUAL ALPHABET, ON EVERY KEY", f_desc,
                 rgba(INK, 226), tracking=px(3.0))

    # rule + stats
    d.line([px(X), px(396), px(X + 46), px(396)], fill=rgba(ROSE, 150),
           width=max(1, px(1.2)))
    draw_tracked(d, px(X), px(424), "26 GLYPHS · 3 KEY FACES · 2 THEMES · RUNE PAD",
                 f_stat, rgba(INK_DIM, 208), tracking=px(2.4))

    # url
    draw_tracked(d, px(X), px(592), "github.com/thechrisgrey/sleep-token-kb",
                 f_url, rgba(INK_DIM, 130), tracking=px(0.9))

    # ------------------------------------------------------------------
    # downsample + grain
    # ------------------------------------------------------------------
    out = canvas.convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    out = ImageEnhance.Contrast(out).enhance(1.035)
    out = ImageEnhance.Brightness(out).enhance(1.06)
    noise = Image.effect_noise((W, H), 12).convert("L")
    noise = Image.merge("RGB", (noise, noise, noise))
    out = Image.blend(out, ImageChops.soft_light(out, noise), 0.50)

    out.save(OUT, "PNG", optimize=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")

    # thumbnail proof (link-unfurl size) -- written outside the repo, best effort
    if os.path.isdir(os.path.dirname(OUT_THUMB)):
        out.resize((500, 250), Image.Resampling.LANCZOS).save(OUT_THUMB, "PNG")
        print("wrote", OUT_THUMB)


if __name__ == "__main__":
    build()
