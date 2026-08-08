#!/usr/bin/env python3
"""
GitHub social preview (Open Graph) image for thechrisgrey/sleep-token-kb.

Direction: "Editorial hero".
Left-weighted type column (real rune eyebrow + New York serif wordmark + italic deck
+ tracked meta rule), two app screenshots tilted and bleeding off the right/bottom,
ambient falling petals in a three-layer depth stack, radial blooms, vignette, grain.

Pure Python 3 + Pillow. Everything is drawn at 3x and LANCZOS-downscaled.
Deterministic: no randomness beyond a fixed-seed grain pass.
"""

import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #

ROOT = "/Users/cperez/dev/delta-centric-dev/sleep-token-kb"
SHOTS = os.path.join(ROOT, "docs", "screenshots")
OUT = os.path.join(ROOT, "docs", "og-editorial.png")
OUT_THUMB = "/private/tmp/claude-501/-Users-cperez-dev-altivum-dev-sleep-token-kb/09ba2e3c-f49f-4058-963f-42064224b8e8/scratchpad/og-editorial-500.png"

F_NY = "/System/Library/Fonts/NewYork.ttf"
F_NYI = "/System/Library/Fonts/NewYorkItalic.ttf"
F_SF = "/System/Library/Fonts/SFNS.ttf"
F_RUNE = os.path.join(ROOT, "SleepTokenKB", "SleepTokenRunes.ttf")

# --------------------------------------------------------------------------- #
# Canvas / palette
# --------------------------------------------------------------------------- #

W, H = 1280, 640
S = 3                      # supersample factor
CW, CH = W * S, H * S

FIELD = (10, 14, 12)
SURFACE = (19, 29, 23)
SURFACE_HIGH = (28, 42, 34)
INK = (237, 230, 209)
INK_DIM = (163, 166, 148)
ROSE = (222, 148, 171)
ROSE_DEEP = (168, 92, 117)
CHAMPAGNE = (199, 181, 122)
BLUSH = (240, 208, 216)


def px(v):
    """1x design units -> supersampled device pixels."""
    return int(round(v * S))


def rgba(c, a):
    return (c[0], c[1], c[2], int(round(max(0.0, min(1.0, a)) * 255)))


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(3))


# --------------------------------------------------------------------------- #
# Fonts
# --------------------------------------------------------------------------- #

def font(path, size_1x, variation=None):
    f = ImageFont.truetype(path, px(size_1x))
    if variation:
        try:
            f.set_variation_by_name(variation)
        except Exception:
            pass
    return f


def rune_text(s):
    return "".join(chr(0xE900 + (ord(c) - 97)) for c in s.lower() if c.isalpha())


# --------------------------------------------------------------------------- #
# Text helpers (ink-box positioning + manual tracking)
# --------------------------------------------------------------------------- #

def ink_box(text, f):
    return f.getbbox(text)


def ink_size(text, f):
    b = f.getbbox(text)
    return (b[2] - b[0], b[3] - b[1])


def draw_ink(d, x, y, text, f, fill):
    """Place so that the *ink* top-left lands exactly on (x, y)."""
    b = f.getbbox(text)
    d.text((x - b[0], y - b[1]), text, font=f, fill=fill)
    return (b[2] - b[0], b[3] - b[1])


def tracked_width(text, f, track, word_gap=None):
    if not text:
        return 0
    total = 0.0
    for i, ch in enumerate(text):
        if ch == " ":
            total += (word_gap if word_gap is not None else f.getlength(" ")) + track
            continue
        total += f.getlength(ch) + track
    return total - track


def draw_tracked(d, x, y_top, text, f, fill, track, word_gap=None, ref=None):
    """
    Draw char-by-char with manual tracking.
    y_top is the ink top of the *reference* string (defaults to `text`), so a line
    keeps a stable optical top even if individual glyphs are short.
    """
    ref = ref if ref is not None else text
    rb = f.getbbox(ref)
    cur = float(x)
    for ch in text:
        if ch == " ":
            cur += (word_gap if word_gap is not None else f.getlength(" ")) + track
            continue
        d.text((cur, y_top - rb[1]), ch, font=f, fill=fill)
        cur += f.getlength(ch) + track
    return cur - track - x


# --------------------------------------------------------------------------- #
# Soft radial bloom
# --------------------------------------------------------------------------- #

def bloom(base, cx, cy, rx, ry, color, peak, power=1.0, steps=110, n=200):
    """Composite a smooth elliptical glow onto an RGBA base (device px)."""
    g = Image.new("L", (n, n), 0)
    gd = ImageDraw.Draw(g)
    half = n / 2.0
    for i in range(steps, 0, -1):
        t = i / steps
        s = 1.0 - t
        falloff = (s * s * (3.0 - 2.0 * s)) ** power     # smoothstep, shaped
        v = int(round(peak * falloff * 255))
        r = t * half
        gd.ellipse([half - r, half - r, half + r, half + r], fill=v)
    g = g.resize((max(2, int(2 * rx)), max(2, int(2 * ry))), Image.LANCZOS)

    mask = Image.new("L", base.size, 0)
    mask.paste(g, (int(cx - rx), int(cy - ry)))
    layer = Image.new("RGBA", base.size, color + (0,))
    layer.putalpha(mask)
    base.alpha_composite(layer)


def vignette(base, strength=0.62, rx_f=0.80, ry_f=0.86, power=1.35):
    n = 220
    g = Image.new("L", (n, n), 0)
    gd = ImageDraw.Draw(g)
    half = n / 2.0
    steps = 120
    for i in range(steps, 0, -1):
        t = i / steps
        s = 1.0 - t
        v = int(round((s * s * (3.0 - 2.0 * s)) ** power * 255))
        r = t * half
        gd.ellipse([half - r, half - r, half + r, half + r], fill=v)
    rx = int(base.size[0] * rx_f)
    ry = int(base.size[1] * ry_f)
    g = g.resize((2 * rx, 2 * ry), Image.LANCZOS)
    mask = Image.new("L", base.size, 0)
    mask.paste(g, (base.size[0] // 2 - rx, base.size[1] // 2 - ry))
    mask = ImageChops.invert(mask).point(lambda v: int(v * strength))
    layer = Image.new("RGBA", base.size, (2, 4, 3, 0))
    layer.putalpha(mask)
    base.alpha_composite(layer)


# --------------------------------------------------------------------------- #
# Petals
# --------------------------------------------------------------------------- #

def hash01(i, salt):
    x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
    return x - math.floor(x)


def _quad(p0, c, p1, n=22):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0],
                    u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1]))
    return pts


def petal_outline(w, h):
    """Petal in a w x h box, origin at box top-left (from the app's motif)."""
    a = (0.50 * w, h)
    b = (0.50 * w, 0.0)
    pts = _quad(a, (1.08 * w, 0.42 * h), b)
    pts += _quad(b, (-0.02 * w, 0.55 * h), a)[1:]
    return pts


def draw_petal(d, cx, cy, size, angle_deg, color, alpha):
    w = size * 0.62
    h = size
    pts = petal_outline(w, h)
    ca = math.cos(math.radians(angle_deg))
    sa = math.sin(math.radians(angle_deg))
    ox, oy = w / 2.0, h / 2.0
    out = []
    for (x, y) in pts:
        dx, dy = x - ox, y - oy
        out.append((cx + dx * ca - dy * sa, cy + dx * sa + dy * ca))
    d.polygon(out, fill=rgba(color, alpha))


def petal_layer(size, specs, blur=0.0):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for sp in specs:
        draw_petal(d, *sp)
    if blur > 0:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return layer


def make_petals(count, salt, size_range, alpha_range, x_bias=0.70,
                y_lo=-0.05, y_hi=1.06, avoid=None):
    """Deterministic petal specs in device px. `avoid` = (x0,y0,x1,y1) 1x rect."""
    specs = []
    for i in range(count):
        u = hash01(i, salt)
        v = hash01(i, salt + 3.7)
        r = hash01(i, salt + 11.3)
        q = hash01(i, salt + 19.1)
        k = hash01(i, salt + 27.5)

        x = W * (u ** x_bias)
        y = H * (y_lo + (y_hi - y_lo) * v)
        size = lerp(size_range[0], size_range[1], r)
        if avoid:
            x0, y0, x1, y1 = avoid
            if x0 - size < x < x1 + size and y0 - size < y < y1 + size:
                continue
        ang = q * 360.0
        alpha = lerp(alpha_range[0], alpha_range[1], k)
        color = mix(BLUSH, ROSE_DEEP, hash01(i, salt + 41.9) ** 0.85)
        specs.append((px(x), px(y), px(size), ang, color, alpha))
    return specs


# --------------------------------------------------------------------------- #
# Phone screenshots
# --------------------------------------------------------------------------- #

def _diag_ramp(w, h, power=3.1, n=72):
    """0..255 falloff, brightest at the top-left corner. Key light lives there."""
    g = Image.new("L", (n, n))
    p = g.load()
    for yy in range(n):
        for xx in range(n):
            t = (xx / (n - 1)) * 0.52 + (yy / (n - 1)) * 0.48
            s = 1.0 - (t * t * (3.0 - 2.0 * t))
            p[xx, yy] = int(round((s ** power) * 255))
    return g.resize((w, h), Image.LANCZOS)


def rounded_mask(w, h, radius, aa=3):
    m = Image.new("L", (w * aa, h * aa), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, w * aa - 1, h * aa - 1], radius=radius * aa, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def phone(path, width_1x, angle, center_1x, shadow=(0, 16, 34, 0.55),
          border_alpha=0.30, tint=None, lift=(1.0, 1.0, 1.0), dof=0.0, halo=None,
          sheen=0.0):
    """
    Returns a list of (image, xy) layers to composite in order.
    angle: degrees, negative = clockwise tilt.
    shadow: (dx, dy, blur, alpha) in 1x units.
    halo:   (dx, dy, blur, alpha, color) - a warm backlight behind the slab.
    sheen:  peak alpha of the diagonal glass highlight.
    lift:   (gamma, contrast, saturation) applied to the screen content. gamma > 1
            opens the shadows without clipping the rose/bone highlights.
    dof:    defocus blur in 1x units - pushes a screen back into the depth field.
    """
    src = Image.open(path).convert("RGB")
    sw, sh = src.size
    w = px(width_1x)
    h = int(round(w * sh / sw))
    body = src.resize((w, h), Image.LANCZOS)

    b, c, s = lift
    if b != 1.0:
        lut = [int(round(255.0 * ((i / 255.0) ** (1.0 / b)))) for i in range(256)]
        body = body.point(lut * 3)
    if c != 1.0:
        body = ImageEnhance.Contrast(body).enhance(c)
    if s != 1.0:
        body = ImageEnhance.Color(body).enhance(s)
    if dof > 0:
        body = body.filter(ImageFilter.GaussianBlur(px(dof)))
    body = body.convert("RGBA")

    radius = int(w * 0.113)
    mask = rounded_mask(w, h, radius)

    # slight tint / atmosphere so the screens sit in the field
    if tint:
        tl = Image.new("RGBA", (w, h), rgba(tint[0], tint[1]))
        body = Image.alpha_composite(body, tl)

    # One diagonal falloff drives both the glass highlight and the edge light,
    # so the whole slab agrees about where the key light is coming from.
    ramp = _diag_ramp(w, h, power=3.1)

    # glass sheen: a wide, soft specular wash falling off from the top-left,
    # the thing that makes a flat screenshot read as a lit pane of glass
    if sheen > 0:
        sl = Image.new("RGBA", (w, h), INK + (0,))
        sl.putalpha(ramp.point(lambda v: int(v * sheen)))
        body = Image.alpha_composite(body, sl)

    # thin light border, drawn inside - brightest where the light hits, so the
    # edge reads as a lit bevel rather than a uniform outline
    bl = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bl)
    bd.rounded_rectangle([1, 1, w * 2 - 2, h * 2 - 2], radius=radius * 2,
                         outline=rgba(INK, border_alpha), width=max(2, int(S * 1.6)))
    bl = bl.resize((w, h), Image.LANCZOS)
    edge = _diag_ramp(w, h, power=1.0).point(lambda v: int(80 + v * 0.685))
    bl.putalpha(ImageChops.multiply(bl.getchannel("A"), edge))
    body = Image.alpha_composite(body, bl)

    body.putalpha(mask)

    cx, cy = px(center_1x[0]), px(center_1x[1])
    layers = []

    def silhouette(spec, color):
        dx, dy, blur, sa = spec
        img = Image.new("RGBA", (w, h), color + (0,))
        img.putalpha(mask.point(lambda v: int(v * sa)))
        pad = px(blur * 3)
        canvas = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
        canvas.paste(img, (pad, pad))
        canvas = canvas.filter(ImageFilter.GaussianBlur(px(blur)))
        rot = canvas.rotate(angle, resample=Image.BICUBIC, expand=True)
        return (rot, (cx - rot.size[0] // 2 + px(dx), cy - rot.size[1] // 2 + px(dy)))

    if halo:
        hdx, hdy, hblur, halpha, hcolor = halo
        layers.append(silhouette((hdx, hdy, hblur, halpha), hcolor))
    layers.append(silhouette(shadow, (0, 0, 0)))

    rot_body = body.rotate(angle, resample=Image.BICUBIC, expand=True)
    layers.append((rot_body,
                   (cx - rot_body.size[0] // 2, cy - rot_body.size[1] // 2)))
    return layers


# --------------------------------------------------------------------------- #
# Jerry
# --------------------------------------------------------------------------- #

JERRY_BODY = (19, 20, 22)
JERRY_LEG = (194, 79, 97)
JERRY_BEAK = (235, 227, 209)


def _stamp_stroke(d, pts, width, color):
    """Round-capped stroke built from overlapping discs - PIL's own line joins
    stair-step badly on the shallow curves of the neck."""
    r = width / 2.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = max(2, int(math.hypot(x1 - x0, y1 - y0) / max(0.6, r * 0.55)) + 1)
        for i in range(steps + 1):
            t = i / steps
            cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


def draw_jerry(size_h, oversample=4):
    """Jerry the black flamingo: black body, white beak, pink legs. Drawn
    oversampled so his curves stay clean at the small size he is placed at."""
    k = size_h * oversample / 150.0
    pad = 16 * k
    w = int(100 * k + pad * 2)
    h = int(150 * k + pad * 2)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")

    def P(p):
        return (pad + p[0] * k, pad + p[1] * k)

    def Q(p0, c, p1, n=48):
        return [P(pt) for pt in _quad(p0, c, p1, n)]

    # legs first, so the body overlaps their tops
    lw = 2.3 * k
    _stamp_stroke(d, [P((52, 84)), P((50, 138))], lw, JERRY_LEG)
    _stamp_stroke(d, [P((50, 138)), P((59, 141))], lw, JERRY_LEG)
    _stamp_stroke(d, [P((61, 84)), P((65, 101)), P((55, 108))], lw, JERRY_LEG)

    body = (Q((30, 62), (36, 46), (56, 48)) + Q((56, 48), (74, 48), (80, 66))
            + Q((80, 66), (78, 88), (52, 88)) + Q((52, 88), (32, 82), (30, 62)))
    d.polygon(body, fill=JERRY_BODY)
    _stamp_stroke(d, Q((74, 62), (90, 52), (82, 34)) + Q((82, 34), (76, 16), (64, 18)),
                  7 * k, JERRY_BODY)
    d.ellipse([P((57, 11)), P((70, 24))], fill=JERRY_BODY)
    _stamp_stroke(d, Q((65, 16), (74, 18), (71, 30)), 4 * k, JERRY_BEAK)

    return img.resize((max(1, w // oversample), max(1, h // oversample)),
                      Image.LANCZOS)


# --------------------------------------------------------------------------- #
# Build
# --------------------------------------------------------------------------- #

# Petals must never settle inside the counters of the wordmark - at this size a
# stray blush triangle in the eye of an 'e' reads as dirt on the lens.
WORDMARK_KEEPOUT = (62, 198, 676, 304)


def build():
    base = Image.new("RGBA", (CW, CH), FIELD + (255,))

    # --- ground gradient (top slightly lifted) -----------------------------
    g = Image.new("L", (2, 64))
    gd = ImageDraw.Draw(g)
    for i in range(64):
        t = i / 63.0
        gd.line([(0, i), (1, i)], fill=int(round(lerp(46, 0, t ** 0.75))))
    g = g.resize((CW, CH), Image.LANCZOS)
    lift = Image.new("RGBA", (CW, CH), SURFACE + (0,))
    lift.putalpha(g)
    base.alpha_composite(lift)

    # --- ambient blooms ----------------------------------------------------
    bloom(base, px(920), px(240), px(600), px(500), ROSE_DEEP, 0.27, power=1.2)
    bloom(base, px(1130), px(105), px(400), px(330), ROSE, 0.13, power=1.5)
    bloom(base, px(258), px(300), px(545), px(455), SURFACE_HIGH, 0.62, power=1.15)
    bloom(base, px(300), px(262), px(300), px(225), CHAMPAGNE, 0.065, power=1.6)
    bloom(base, px(620), px(716), px(780), px(330), (4, 6, 5), 0.5, power=1.1)
    # a whisper of rose carried into the quiet lower left, so the pinks read
    # across the whole field rather than only under the screenshots
    bloom(base, px(196), px(556), px(430), px(300), ROSE_DEEP, 0.075, power=1.45)
    bloom(base, px(120), px(430), px(330), px(300), SURFACE_HIGH, 0.28, power=1.3)

    # --- far petals (behind everything, soft) ------------------------------
    far = make_petals(34, salt=1.0, size_range=(20, 42), alpha_range=(0.06, 0.16),
                      x_bias=0.72, y_lo=-0.05, y_hi=1.05, avoid=WORDMARK_KEEPOUT)
    base.alpha_composite(petal_layer((CW, CH), far, blur=px(2.6)))

    # --- mid petals (behind phones, sharp) ---------------------------------
    mid = make_petals(44, salt=7.0, size_range=(9, 23), alpha_range=(0.12, 0.36),
                      x_bias=0.70, y_lo=-0.04, y_hi=1.04, avoid=WORDMARK_KEEPOUT)
    base.alpha_composite(petal_layer((CW, CH), mid, blur=px(0.35)))

    # ---------------------------------------------------------------------- #
    # Screenshots
    # ---------------------------------------------------------------------- #
    # Key light reads from the upper left, so both slabs throw down and to the
    # right - which also drops the front phone's shadow onto the back one and
    # keeps the pair from fusing into a single mass.
    back = phone(
        os.path.join(SHOTS, "alphabet-arcadia.png"),
        width_1x=330, angle=-12, center_1x=(1206, 318),
        shadow=(10, 20, 34, 0.60), border_alpha=0.24,
        # Lifted and de-hazed relative to the first pass: at unfurl size the
        # heavier haze collapsed this slab into a dark smear against the
        # bloom. It still recedes (softer, dimmer, defocused) but now reads
        # as a second device carrying glyph cards.
        lift=(1.52, 1.30, 1.16), dof=1.5, sheen=0.075,
        tint=((10, 16, 13), 0.14),
        halo=(-10, -8, 30, 0.18, ROSE_DEEP))
    front = phone(
        os.path.join(SHOTS, "runepad-arcadia.png"),
        width_1x=320, angle=-7, center_1x=(910, 396),
        shadow=(18, 24, 26, 0.80), border_alpha=0.36,
        lift=(1.10, 1.12, 1.06), sheen=0.07,
        halo=(-16, -12, 34, 0.28, ROSE_DEEP))

    for (img, xy) in back + front:
        base.alpha_composite(img, xy)

    # --- near petals (in front of the phones) ------------------------------
    near = make_petals(17, salt=23.0, size_range=(26, 54), alpha_range=(0.12, 0.28),
                       x_bias=0.42, y_lo=-0.02, y_hi=1.04,
                       avoid=(40, 150, 730, 480))
    base.alpha_composite(petal_layer((CW, CH), near, blur=px(3.4)))

    # ---------------------------------------------------------------------- #
    # Type column
    # ---------------------------------------------------------------------- #
    d = ImageDraw.Draw(base)

    MARGIN = 76.0

    f_rune = font(F_RUNE, 38)
    f_mark = font(F_NY, 88, "Medium")
    f_deck = font(F_NYI, 26.5, "Regular Italic")
    f_meta = font(F_SF, 12.8, "Medium")
    f_foot = font(F_SF, 12.8, "Regular")

    RUNES = rune_text("sleep") + " " + rune_text("token")
    MARK = "Sleep Token KB"
    DECK = "The ritual alphabet, on every key."
    META = "26 GLYPHS  ·  3 KEY FACES  ·  2 THEMES  ·  RUNE PAD"
    FOOT = "github.com/thechrisgrey/sleep-token-kb"

    rune_track = px(11.0)
    rune_gap = px(30.0)
    meta_track = px(3.3)
    meta_space = f_meta.getlength(" ")

    h_rune = ink_size(RUNES.replace(" ", ""), f_rune)[1]
    h_mark = ink_size(MARK, f_mark)[1]
    h_deck = ink_size(DECK, f_deck)[1]
    h_meta = ink_size("EGH", f_meta)[1]
    h_foot = ink_size("github", f_foot)[1]

    G1 = px(32)     # runes -> wordmark
    G2 = px(31)     # wordmark -> deck
    G3 = px(29)     # deck -> rule
    RULE = px(1.4)
    G4 = px(23)     # rule -> meta
    G5 = px(26)     # meta -> colophon

    total = (h_rune + G1 + h_mark + G2 + h_deck + G3 + RULE + G4
             + h_meta + G5 + h_foot)
    # optical centre sits a touch above the geometric centre: the wordmark's
    # weight is top-heavy in the stack, and the phones fall away to the lower right
    y = px(314) - total // 2
    x = px(MARGIN)

    draw_tracked(d, x, y, RUNES, f_rune, rgba(ROSE, 0.98), rune_track,
                 word_gap=rune_gap, ref=RUNES.replace(" ", ""))
    y += h_rune + G1

    draw_ink(d, x, y, MARK, f_mark, rgba(CHAMPAGNE, 1.0))
    y += h_mark + G2

    draw_ink(d, x + px(1.5), y, DECK, f_deck, rgba(INK, 0.88))
    y += h_deck + G3

    d.rectangle([x, y, x + px(64), y + RULE - 1], fill=rgba(ROSE, 0.78))
    y += RULE + G4

    draw_tracked(d, x + px(1), y, META, f_meta, rgba(INK_DIM, 0.92), meta_track,
                 word_gap=meta_space, ref="EGH")
    y += h_meta + G5

    draw_tracked(d, x + px(1), y, FOOT, f_foot, rgba(INK_DIM, 0.52),
                 px(0.7), word_gap=f_foot.getlength(" "), ref="github")

    # ---------------------------------------------------------------------- #
    # Jerry
    # ---------------------------------------------------------------------- #
    # He is hidden ten times inside the app; here he stands once, in the open
    # lower gap between the type column and the phones. Sized to be noticed
    # second, after the wordmark - a detail for the people who know him.
    JX, JY = 600, 596                       # feet
    jh = px(104)
    jerry = draw_jerry(jh)
    jx = px(JX) - jerry.width // 2
    jy = px(JY) - jerry.height

    # A near-black silhouette on a near-black field needs somewhere to be seen
    # against. This pool is the light he stands in; without it he reads as a
    # smudge at unfurl size rather than as a bird.
    bloom(base, px(JX), px(JY - 34), px(196), px(150), SURFACE_HIGH, 0.78, power=1.5)
    bloom(base, px(JX), px(JY - 44), px(124), px(96), ROSE_DEEP, 0.26, power=1.7)
    # Padded canvas: without room for the blur to fall off, the Gaussian is
    # clipped at the image bounds and the "soft" shadow renders as a dark bar
    # with hard vertical edges.
    sw, sh, spad = px(104), px(20), px(30)
    shadow = Image.new("RGBA", (sw + spad * 2, sh + spad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([spad, spad, spad + sw - 1, spad + sh - 1],
                                   fill=(0, 0, 0, 105))
    shadow = shadow.filter(ImageFilter.GaussianBlur(px(9)))
    base.alpha_composite(shadow, (px(JX) - sw // 2 - spad, px(JY - 6) - sh // 2 - spad))
    base.alpha_composite(jerry, (jx, jy))

    # ---------------------------------------------------------------------- #
    # Atmosphere
    # ---------------------------------------------------------------------- #
    vignette(base, strength=0.52, rx_f=0.86, ry_f=0.92)

    out = base.convert("RGB").resize((W, H), Image.LANCZOS)
    out = out.filter(ImageFilter.UnsharpMask(radius=0.8, percent=42, threshold=2))

    # film grain (fixed seed, added at final resolution so it stays fine)
    random.seed(20260726)
    noise = Image.frombytes("L", (W, H), bytes(random.getrandbits(8) for _ in range(W * H)))
    noise = noise.filter(ImageFilter.GaussianBlur(0.42))
    noise = noise.point(lambda v: 128 + int((v - 128) * 0.30))
    grained = ImageChops.overlay(out, noise.convert("RGB"))
    out = Image.blend(out, grained, 0.44)

    out.save(OUT, optimize=True)
    out.resize((500, 250), Image.LANCZOS).save(OUT_THUMB, optimize=True)
    print("wrote", OUT, out.size, f"{os.path.getsize(OUT)/1024:.0f} KB")
    print("wrote", OUT_THUMB)


if __name__ == "__main__":
    build()
