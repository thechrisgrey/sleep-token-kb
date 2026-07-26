#!/usr/bin/env python3
"""Build SleepTokenRunes.ttf from stkb-runes-svg/symbol_a.svg .. symbol_z.svg.

Each SVG traces one ritual glyph as a mix of stroked paths/circles/ellipses
(centerlines with a stroke-width, fill-opacity:0) and a few filled dots
(fill-opacity:1). TrueType outlines are filled regions, so every stroked
shape is expanded to its inked outline (buffered by half its stroke width,
round caps/joins) before being unioned into one glyph contour.

Requires: fontTools, svgelements, shapely (see requirements.txt).
Usage:
    python3 scripts/build_rune_font.py [output.ttf]
"""
import sys
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from svgelements import SVG
from shapely.geometry import Polygon, LinearRing, LineString
from shapely.ops import unary_union
from shapely.geometry.polygon import orient

REPO_ROOT = Path(__file__).resolve().parent.parent
SVG_DIR = REPO_ROOT / "stkb-runes-svg"
LETTERS = "abcdefghijklmnopqrstuvwxyz"
PUA_BASE = 0xE900

UNITS_PER_EM = 1000
TARGET_CAP_HEIGHT = 650  # visual height of the tallest glyph, in font units
TARGET_MID_Y = 300  # every glyph is vertically centered on this line, regardless
# of its own height — the source SVGs are icon-style traces (flat bars, tall
# rings, everything in between) with no shared baseline concept, so each glyph
# is centered like a keycap icon rather than baseline-anchored like text.
SIDE_BEARING = 60  # left/right margin added to every glyph's advance width
SAMPLES_PER_CURVE = 16  # points used to flatten each Bezier/Arc segment
BUFFER_RESOLUTION = 8  # segments per quarter-circle when expanding strokes


def flatten_segment(seg, samples):
    """Return a list of (x, y) points approximating one svgelements segment."""
    kind = type(seg).__name__
    if kind == "Move":
        return [(seg.end.x, seg.end.y)]
    if kind == "Close":
        return [(seg.end.x, seg.end.y)]
    if kind == "Line":
        return [(seg.end.x, seg.end.y)]
    # CubicBezier, QuadraticBezier, Arc all support .point(t)
    pts = []
    for i in range(1, samples + 1):
        t = i / samples
        p = seg.point(t)
        pts.append((p.x, p.y))
    return pts


def shape_to_subpaths(shape):
    """Split one svgelements Shape into a list of (points, closed) subpaths."""
    subpaths = []
    current = []
    closed = False
    for seg in shape.segments(transformed=True):
        kind = type(seg).__name__
        if kind == "Move":
            if current:
                subpaths.append((current, closed))
            current = [(seg.end.x, seg.end.y)]
            closed = False
            continue
        if kind == "Close":
            closed = True
            continue
        current.extend(flatten_segment(seg, SAMPLES_PER_CURVE))
    if current:
        subpaths.append((current, closed))
    return subpaths


def shape_ink_polygons(shape):
    """Return shapely polygons representing the inked (filled) area of one shape."""
    fill_alpha = getattr(shape.fill, "alpha", 0) or 0
    stroke_alpha = getattr(shape.stroke, "alpha", 0) or 0
    stroke_width = shape.stroke_width or 0
    polys = []
    for points, closed in shape_to_subpaths(shape):
        if len(points) < 2:
            continue
        if fill_alpha > 0:
            ring_pts = points if points[0] == points[-1] else points + [points[0]]
            if len(ring_pts) >= 4:
                polys.append(Polygon(ring_pts))
        if stroke_alpha > 0 and stroke_width > 0:
            geom = LinearRing(points) if closed else LineString(points)
            polys.append(
                geom.buffer(
                    stroke_width / 2,
                    cap_style="round",
                    join_style="round",
                    quad_segs=BUFFER_RESOLUTION,
                )
            )
    return polys


def build_glyph_geometry(svg_path):
    """Return (unioned shapely geometry, viewbox) for one glyph's SVG file."""
    svg = SVG.parse(str(svg_path))
    polys = []
    for el in svg.elements():
        if hasattr(el, "segments") and hasattr(el, "fill"):
            try:
                polys.extend(shape_ink_polygons(el))
            except Exception as exc:  # noqa: BLE001 - report and skip malformed shape
                print(f"  warning: skipped a shape in {svg_path.name}: {exc}", file=sys.stderr)
    ink = unary_union(polys) if polys else Polygon()
    viewbox = svg.viewbox  # Viewbox(x, y, width, height)
    return ink, viewbox


def polygon_to_contours(geom):
    """Yield (exterior_or_hole, is_hole) point lists for a Polygon/MultiPolygon."""
    geoms = geom.geoms if geom.geom_type == "MultiPolygon" else [geom]
    for g in geoms:
        if g.is_empty:
            continue
        g = orient(g, sign=1.0)  # exterior CCW, holes CW
        yield list(g.exterior.coords)[:-1], False
        for interior in g.interiors:
            yield list(interior.coords)[:-1], True


def draw_glyph(pen, geom, transform):
    """Draw a shapely geometry into a TTGlyphPen using `transform(x, y) -> (x, y)`."""
    contour_count = 0
    for points, _ in polygon_to_contours(geom):
        if len(points) < 3:
            continue
        pts = [transform(x, y) for x, y in points]
        pen.moveTo(pts[0])
        for pt in pts[1:]:
            pen.lineTo(pt)
        pen.closePath()
        contour_count += 1
    return contour_count


def main():
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO_ROOT / "SleepTokenRunes.ttf"

    raw = {}  # letter -> (ink geometry, viewbox)
    max_height = 0.0
    for letter in LETTERS:
        svg_path = SVG_DIR / f"symbol_{letter}.svg"
        ink, viewbox = build_glyph_geometry(svg_path)
        raw[letter] = (ink, viewbox)
        max_height = max(max_height, viewbox.height)

    scale = TARGET_CAP_HEIGHT / max_height

    glyph_order = [".notdef"] + [f"rune_{letter}" for letter in LETTERS]
    char_map = {PUA_BASE + i: f"rune_{letter}" for i, letter in enumerate(LETTERS)}

    glyphs = {}
    metrics = {}

    notdef_pen = TTGlyphPen(None)
    box = UNITS_PER_EM * 0.05
    notdef_pen.moveTo((box, 0))
    notdef_pen.lineTo((UNITS_PER_EM - box, 0))
    notdef_pen.lineTo((UNITS_PER_EM - box, TARGET_CAP_HEIGHT))
    notdef_pen.lineTo((box, TARGET_CAP_HEIGHT))
    notdef_pen.closePath()
    glyphs[".notdef"] = notdef_pen.glyph()
    metrics[".notdef"] = (UNITS_PER_EM, 0)

    for letter in LETTERS:
        ink, viewbox = raw[letter]
        min_x = viewbox.x
        min_y = viewbox.y
        half_height = viewbox.height * scale / 2

        def transform(x, y, _min_x=min_x, _min_y=min_y, _vb_h=viewbox.height, _half_h=half_height):
            from_bottom = (_vb_h - (y - _min_y)) * scale
            return (
                round((x - _min_x) * scale + SIDE_BEARING),
                round(TARGET_MID_Y - _half_h + from_bottom),
            )

        pen = TTGlyphPen(None)
        contour_count = draw_glyph(pen, ink, transform)
        name = f"rune_{letter}"
        glyphs[name] = pen.glyph()
        advance = round(viewbox.width * scale) + 2 * SIDE_BEARING
        metrics[name] = (advance, SIDE_BEARING)
        print(f"  {name}: {contour_count} contour(s), advance={advance}")

    fb = FontBuilder(UNITS_PER_EM, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(char_map)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=UNITS_PER_EM - 200, descent=-200)
    fb.setupNameTable(
        {
            "familyName": "SleepTokenRunes",
            "styleName": "Regular",
            "uniqueFontIdentifier": "ai.altivum.SleepTokenRunes",
            "fullName": "SleepTokenRunes",
            "version": "Version 2.0",
            "psName": "SleepTokenRunes-Regular",
        }
    )
    fb.setupOS2(sTypoAscender=UNITS_PER_EM - 200, sTypoDescender=-200, usWinAscent=UNITS_PER_EM, usWinDescent=200)
    fb.setupPost()

    fb.save(str(out_path))
    print(f"\nWrote {out_path}")


if __name__ == "__main__":
    main()
