#!/usr/bin/env python3
"""
Open Graph / social preview image for thechrisgrey/sleep-token-kb.

Direction: GLYPH-FORWARD MINIMAL.
The ritual alphabet is the hero. One enormous inscription band of real rune
glyphs spelling "sleep token" runs the full measure and bleeds off both edges,
lit from behind on a near-black green field. The Latin wordmark sits small and
quiet beneath it. Jerry the black flamingo is the only figurative element --
a silhouette in the lower right, there to be discovered rather than announced.

Pure Python 3 + Pillow. Drawn at 3x and LANCZOS-downscaled to 1280x640.
"""

import math
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

# ----------------------------------------------------------------------------
# constants
# ----------------------------------------------------------------------------

ROOT = "/Users/cperez/dev/delta-centric-dev/sleep-token-kb"
OUT = os.path.join(ROOT, "docs", "og-glyph.png")
OUT_THUMB = "/private/tmp/claude-501/-Users-cperez-dev-altivum-dev-sleep-token-kb/09ba2e3c-f49f-4058-963f-42064224b8e8/scratchpad/og-glyph-500.png"

W, H = 1280, 640
SS = 3                      # supersample factor
CW, CH = W * SS, H * SS

RUNE_FONT = os.path.join(ROOT, "SleepTokenKB", "SleepTokenRunes.ttf")
NY = "/System/Library/Fonts/NewYork.ttf"
SF = "/System/Library/Fonts/SFNS.ttf"

# palette -- Theme.swift, "Even in Arcadia"
FIELD = (10, 14, 12)
SURFACE = (19, 29, 23)
SURFACE_HIGH = (28, 42, 34)
INK = (237, 230, 209)
INK_DIM = (163, 166, 148)
ROSE = (222, 148, 171)
ROSE_DEEP = (168, 92, 117)
CHAMPAGNE = (199, 181, 122)

JERRY_BODY = (13, 14, 16)
JERRY_LEG = (194, 79, 97)
JERRY_BEAK = (235, 227, 209)


def rune(s):
    return "".join(chr(0xE900 + (ord(c) - 97)) for c in s if c.isalpha())


# ----------------------------------------------------------------------------
# small helpers
# ----------------------------------------------------------------------------

def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(3))


def vgrad(size, stops):
    """Vertical gradient. stops = [(pos 0..1, (r,g,b)), ...] ascending."""
    w, h = size
    strip = Image.new("RGB", (1, 512))
    px = strip.load()
    for y in range(512):
        t = y / 511.0
        lo = stops[0]
        hi = stops[-1]
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                lo, hi = stops[i], stops[i + 1]
                break
        span = max(1e-6, hi[0] - lo[0])
        px[0, y] = mix(lo[1], hi[1], (t - lo[0]) / span)
    return strip.resize((w, h), Image.BICUBIC)


_RADIAL_CACHE = {}


def radial_mask(power=2.2, res=256):
    """L-mode radial falloff, 255 at centre -> 0 at the inscribed circle."""
    key = (power, res)
    if key in _RADIAL_CACHE:
        return _RADIAL_CACHE[key]
    m = Image.new("L", (res, res), 0)
    px = m.load()
    c = (res - 1) / 2.0
    for y in range(res):
        dy = (y - c) / c
        for x in range(res):
            dx = (x - c) / c
            r = math.hypot(dx, dy)
            v = 0.0 if r >= 1.0 else (1.0 - r) ** power
            px[x, y] = int(v * 255)
    m = m.filter(ImageFilter.GaussianBlur(res / 90.0))
    _RADIAL_CACHE[key] = m
    return m


def bloom(layer, cx, cy, rx, ry, color, alpha, power=2.2):
    """Composite a soft radial glow onto an RGB layer."""
    rx, ry = int(rx), int(ry)
    if rx < 2 or ry < 2:
        return
    m = radial_mask(power).resize((rx * 2, ry * 2), Image.BICUBIC)
    m = m.point(lambda v: int(v * alpha))
    tile = Image.new("RGB", m.size, color)
    layer.paste(tile, (int(cx - rx), int(cy - ry)), m)


def quad(p0, c, p1, n=32):
    """Flatten a quadratic bezier."""
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0],
                    u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1]))
    return pts


def var_font(path, size, weight=None, optical=None, width=None):
    f = ImageFont.truetype(path, size)
    try:
        axes = f.get_variation_axes()
        vals = [a["default"] for a in axes]
        for i, a in enumerate(axes):
            name = a["name"].decode() if isinstance(a["name"], bytes) else a["name"]
            if name == "Weight" and weight is not None:
                vals[i] = max(a["minimum"], min(a["maximum"], weight))
            elif name == "Optical Size" and optical is not None:
                vals[i] = max(a["minimum"], min(a["maximum"], optical))
            elif name == "Width" and width is not None:
                vals[i] = max(a["minimum"], min(a["maximum"], width))
        f.set_variation_by_axes(vals)
    except Exception:
        pass
    return f


def tracked_width(font, text, track):
    if not text:
        return 0.0
    return sum(font.getlength(c) for c in text) + track * (len(text) - 1)


def draw_tracked(draw, x, y, text, font, fill, track, anchor="ls"):
    """Draw letter-spaced text. x is the left edge unless anchor starts with 'm'."""
    total = tracked_width(font, text, track)
    if anchor[0] == "m":
        x -= total / 2.0
    elif anchor[0] == "r":
        x -= total
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill, anchor="l" + anchor[1])
        x += font.getlength(ch) + track
    return total


# ----------------------------------------------------------------------------
# rune typesetting
# ----------------------------------------------------------------------------

def glyph_mask(ch, size):
    """Render one rune to an L image cropped tight to its ink."""
    font = ImageFont.truetype(RUNE_FONT, int(size))
    pad = int(size)
    canvas = Image.new("L", (int(size * 3), int(size * 3)), 0)
    d = ImageDraw.Draw(canvas)
    d.text((pad, pad * 2), rune(ch), font=font, fill=255, anchor="ls")
    bb = canvas.getbbox()
    return canvas.crop(bb)


def rune_band(words, size, track_frac=0.16, word_frac=0.32):
    """
    Set words as one horizontal inscription: ink boxes separated by a constant
    optical gap, every glyph vertically ink-centred on a shared axis, an extra
    measure of air between words. The font has no space glyph, so the word gap
    is advanced by hand.
    """
    track = track_frac * size
    wgap = track + word_frac * size
    items = []
    for wi, word in enumerate(words):
        if wi:
            items.append(None)
        items.extend(glyph_mask(c, size) for c in word)

    h = max(g.height for g in items if g is not None)
    total = 0.0
    prev_glyph = False
    for it in items:
        if it is None:
            total += wgap
            prev_glyph = False
        else:
            if prev_glyph:
                total += track
            total += it.width
            prev_glyph = True

    mask = Image.new("L", (int(round(total)) + 4, h), 0)
    x = 0.0
    prev_glyph = False
    for it in items:
        if it is None:
            x += wgap
            prev_glyph = False
            continue
        if prev_glyph:
            x += track
        mask.paste(it, (int(round(x)), int(round((h - it.height) / 2.0))), it)
        x += it.width
        prev_glyph = True
    return mask.crop(mask.getbbox())


def rune_band_fitted(words, target_width, track_frac=0.16, word_frac=0.32):
    """Solve for the rune size that makes the band exactly `target_width` wide."""
    probe = 200
    m = rune_band(words, probe, track_frac, word_frac)
    size = probe * target_width / m.width
    return rune_band(words, size, track_frac, word_frac), size


# ----------------------------------------------------------------------------
# motifs
# ----------------------------------------------------------------------------

def hash01(i, salt):
    x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
    return x - math.floor(x)


def petal_polygon(w, h, angle_deg, cx, cy):
    pts = quad((0.5 * w, h), (1.08 * w, 0.42 * h), (0.5 * w, 0.0), 20)
    pts += quad((0.5 * w, 0.0), (-0.02 * w, 0.55 * h), (0.5 * w, h), 20)
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    out = []
    for px, py in pts:
        dx, dy = px - 0.5 * w, py - 0.5 * h
        out.append((cx + dx * ca - dy * sa, cy + dx * sa + dy * ca))
    return out


def draw_petals(layer, cols, rows, seed=3.0, avoid=None, keep=0.55):
    """
    Sparse falling petals, stratified over a coarse grid so they never clump,
    then softened so they read as drift rather than dust.
    """
    d = ImageDraw.Draw(layer, "RGBA")
    for r in range(rows):
        for c in range(cols):
            i = r * cols + c + 1
            if hash01(i, seed + 61) > keep:
                continue
            x = (c + 0.15 + 0.70 * hash01(i, seed)) * CW / cols
            y = (r + 0.15 + 0.70 * hash01(i, seed + 11)) * CH / rows
            if avoid and any(ax0 < x < ax1 and ay0 < y < ay1
                             for ax0, ay0, ax1, ay1 in avoid):
                continue
            s = (9 + hash01(i, seed + 21) * 9) * SS
            ang = hash01(i, seed + 31) * 360.0
            t = hash01(i, seed + 41)
            col = mix((208, 140, 164), (240, 220, 220), t)
            a = int(30 + hash01(i, seed + 51) * 44)
            d.polygon(petal_polygon(s, s * 1.85, ang, x, y), fill=col + (a,))


def stamp_stroke(draw, pts, width, fill, step=0.6):
    """Round-capped, perfectly smooth stroke: stamp discs along a polyline."""
    r = width / 2.0
    prev = None
    for p in pts:
        if prev is not None:
            seg = math.dist(prev, p)
            n = max(1, int(seg / step))
            for i in range(1, n + 1):
                t = i / n
                x = lerp(prev[0], p[0], t)
                y = lerp(prev[1], p[1], t)
                draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)
        else:
            draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=fill)
        prev = p


def draw_jerry(size_h, oversample=3):
    """
    Jerry the black flamingo. Drawn oversampled and downscaled so every
    curve is clean at the tiny size he is actually placed at.
    """
    k = size_h * oversample / 150.0
    pad = 16 * k
    ox, oy = pad, pad
    w = int(100 * k + pad * 2)
    h = int(150 * k + pad * 2)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")

    def P(p):
        return (ox + p[0] * k, oy + p[1] * k)

    def Q(p0, c, p1, n=48):
        return [P(pt) for pt in quad(p0, c, p1, n)]

    # body + neck + head silhouette, all one colour
    body = []
    body += Q((30, 62), (36, 46), (56, 48))
    body += Q((56, 48), (74, 48), (80, 66))
    body += Q((80, 66), (78, 88), (52, 88))
    body += Q((52, 88), (32, 82), (30, 62))

    neck = Q((74, 62), (90, 52), (82, 34)) + Q((82, 34), (76, 16), (64, 18))

    # legs sit behind the body
    lw = 2.3 * k
    stamp_stroke(d, [P((52, 84)), P((50, 138))], lw, JERRY_LEG)
    stamp_stroke(d, [P((50, 138)), P((59, 141))], lw, JERRY_LEG)
    stamp_stroke(d, [P((61, 84)), P((65, 101)), P((55, 108))], lw, JERRY_LEG)

    d.polygon(body, fill=JERRY_BODY)
    stamp_stroke(d, neck, 7 * k, JERRY_BODY)
    d.ellipse([P((57, 11)), P((70, 24))], fill=JERRY_BODY)

    # beak last, in bone
    stamp_stroke(d, Q((65, 16), (74, 18), (71, 30)), 4 * k, JERRY_BEAK)

    return img.resize((max(1, w // oversample), max(1, h // oversample)),
                      Image.LANCZOS)


# ----------------------------------------------------------------------------
# composition
# ----------------------------------------------------------------------------

def build():
    # ---- field ------------------------------------------------------------
    base = vgrad((CW, CH), [
        (0.00, (6, 10, 8)),
        (0.22, (11, 16, 13)),
        (0.52, (13, 19, 15)),
        (0.80, (9, 13, 11)),
        (1.00, (6, 9, 8)),
    ])

    # deep blooms: rose above, green core, cool corners
    bloom(base, CW * 0.50, CH * 0.24, CW * 0.54, CH * 0.60, (58, 32, 45), 0.56, power=2.6)
    bloom(base, CW * 0.50, CH * 0.40, CW * 0.32, CH * 0.40, (34, 56, 43), 0.50, power=2.2)
    bloom(base, CW * 0.14, CH * 0.14, CW * 0.30, CH * 0.34, (26, 42, 33), 0.36, power=2.4)
    # a pool of light for Jerry to be discovered in
    bloom(base, CW * 0.905, CH * 0.80, CW * 0.30, CH * 0.50, (42, 57, 47), 0.46, power=2.5)

    # horizon shelf: the inscription reads as emerging from a band of light
    shelf = Image.new("RGB", (CW, CH), (0, 0, 0))
    bloom(shelf, CW * 0.50, 250 * SS, CW * 0.66, 168 * SS, (17, 26, 21), 1.0, power=1.9)
    base = ImageChops.add(base, shelf)

    img = base.convert("RGBA")

    # ---- rune inscription -------------------------------------------------
    # one band, spanning the full measure and bleeding a sliver off both
    # edges so the writing reads as continuing past the frame
    BAND_W = 1322 * SS
    band, RS = rune_band_fitted(["sleep", "token"], BAND_W, 0.155, 0.34)
    band_cy = 248 * SS
    bx = int(CW / 2 - band.width / 2)
    by = int(band_cy - band.height / 2)
    block_top, block_bot = by, by + band.height

    full = Image.new("L", (CW, CH), 0)
    full.paste(band, (bx, by), band)

    # backlight: wide rose halo + tight champagne halo
    halo_far = full.filter(ImageFilter.GaussianBlur(50 * SS / 3))
    halo_far = halo_far.point(lambda v: min(255, int(v * 0.78)))
    lay = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    lay.paste(Image.new("RGB", (CW, CH), (136, 66, 90)), (0, 0), halo_far)
    img = Image.alpha_composite(img, lay)

    halo_near = full.filter(ImageFilter.GaussianBlur(12 * SS / 3))
    halo_near = halo_near.point(lambda v: min(255, int(v * 0.36)))
    lay = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    lay.paste(Image.new("RGB", (CW, CH), (152, 134, 94)), (0, 0), halo_near)
    img = Image.alpha_composite(img, lay)

    # petals sit between halo and glyphs so they read as depth, not litter
    petals = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    draw_petals(petals, 8, 4, seed=19.0, keep=0.5, avoid=[
        (0, block_top - 26 * SS, CW, block_bot + 26 * SS),
        (270 * SS, 356 * SS, 1010 * SS, 546 * SS),
        (1040 * SS, 470 * SS, CW, CH),
        (0, 556 * SS, 540 * SS, CH),
        (320 * SS, 0, 960 * SS, 112 * SS),
    ])
    petals = petals.filter(ImageFilter.GaussianBlur(2.6 * SS / 3))
    img = Image.alpha_composite(img, petals)

    # glyph fill: bone drifting to champagne down the glyph, and lit from the
    # centre of the band so the cropped ends fall away into the dark
    fill = vgrad((CW, band.height), [
        (0.00, (245, 240, 225)),
        (0.46, (233, 226, 203)),
        (1.00, (203, 187, 142)),
    ])
    ramp = Image.new("L", (CW, 1))
    rp = ramp.load()
    for x in range(CW):
        t = abs(x - CW / 2) / (CW / 2)
        rp[x, 0] = int(255 * (1.0 - 0.44 * t ** 2.1))
    ramp = ramp.resize((CW, band.height), Image.BILINEAR)
    lit = ImageChops.multiply(full.crop((0, block_top, CW, block_bot)), ramp)
    full_rgba = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    full_rgba.paste(fill, (0, block_top), lit)
    img = Image.alpha_composite(img, full_rgba)

    d = ImageDraw.Draw(img, "RGBA")

    # ---- divider ----------------------------------------------------------
    rule_y = 384 * SS
    seg = 150 * SS
    inner = 18 * SS
    for sgn in (-1, 1):
        a = CW / 2 + sgn * inner
        b = CW / 2 + sgn * (inner + seg)
        grad_steps = 26
        for i in range(grad_steps):
            t0 = i / grad_steps
            t1 = (i + 1) / grad_steps
            xa = lerp(a, b, t0)
            xb = lerp(a, b, t1)
            alpha = int(96 * (1.0 - t0) ** 1.25)
            d.line([(xa, rule_y), (xb, rule_y)], fill=CHAMPAGNE + (alpha,),
                   width=max(1, int(1.1 * SS)))
    r = 5.2 * SS
    d.polygon([(CW / 2, rule_y - r), (CW / 2 + r, rule_y),
               (CW / 2, rule_y + r), (CW / 2 - r, rule_y)], fill=ROSE + (240,))

    # ---- kicker, wordmark, descriptor -------------------------------------
    kick_font = var_font(SF, int(11.5 * SS), weight=540, optical=17)
    draw_tracked(d, CW / 2, 100 * SS, "26 GLYPHS   ·   3 KEY FACES   ·   2 THEMES   ·   RUNE PAD",
                 kick_font, (142, 148, 134, 255), 3.4 * SS, anchor="ms")

    wm_font = var_font(NY, int(63 * SS), weight=450, optical=256)
    draw_tracked(d, CW / 2, 474 * SS, "Ceremonial Scripts", wm_font, INK + (255,),
                 2.4 * SS, anchor="ms")

    desc_font = var_font(SF, int(13.5 * SS), weight=530, optical=20)
    draw_tracked(d, CW / 2, 512 * SS, "RITUAL ALPHABET KEYBOARD FOR iOS",
                 desc_font, (184, 187, 169, 248), 4.7 * SS, anchor="ms")

    # ---- footer micro-line ------------------------------------------------
    foot_font = var_font(SF, int(11 * SS), weight=520, optical=17)
    draw_tracked(d, 64 * SS, 601 * SS, "GITHUB.COM/THECHRISGREY/SLEEP-TOKEN-KB",
                 foot_font, (120, 126, 115, 255), 3.0 * SS, anchor="ls")

    # ---- Jerry ------------------------------------------------------------
    jh = 118 * SS
    jerry = draw_jerry(jh)
    jx = int(1146 * SS - jerry.width / 2)
    jy = int(596 * SS - jerry.height + 16 * (jh / 150.0))

    # ground shadow only -- a soft, wide ellipse, never a disc behind him
    sh = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh, "RGBA")
    scx = jx + jerry.width * 0.50
    scy = jy + jerry.height - 18 * (jh / 150.0)
    sd.ellipse([scx - 30 * SS, scy - 5 * SS, scx + 30 * SS, scy + 5 * SS],
               fill=(0, 0, 0, 130))
    sh = sh.filter(ImageFilter.GaussianBlur(12 * SS / 3))
    img = Image.alpha_composite(img, sh)
    img.alpha_composite(jerry, (jx, jy))

    # ---- downscale --------------------------------------------------------
    out = img.convert("RGB").resize((W, H), Image.LANCZOS)

    # ---- vignette ---------------------------------------------------------
    vm = radial_mask(1.5, 256).resize((W, H), Image.BICUBIC)
    vm = vm.point(lambda v: 255 - int(v * 0.92))
    dark = Image.new("RGB", (W, H), (3, 5, 4))
    out = Image.composite(dark, out, vm.point(lambda v: int(v * 0.30)))

    # ---- grain ------------------------------------------------------------
    noise = Image.effect_noise((W, H), 15).convert("RGB")
    out = Image.blend(out, ImageChops.overlay(out, noise), 0.10)

    return out


if __name__ == "__main__":
    im = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT, optimize=True)
    # link-unfurl proof: the size this is actually seen at most of the time
    if os.path.isdir(os.path.dirname(OUT_THUMB)):
        im.resize((500, 250), Image.LANCZOS).save(OUT_THUMB, optimize=True)
    print("wrote %s  %dx%d  %.0f KB"
          % (OUT, im.width, im.height, os.path.getsize(OUT) / 1024))
