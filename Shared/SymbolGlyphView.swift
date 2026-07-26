import SwiftUI
import UIKit

/// Renders a Sleep Token letter: asset catalog image if present, else geometric fallback.
public struct SymbolGlyphView: View {
    public let letter: SleepTokenLetter
    public var foreground: Color = .primary

    public init(letter: SleepTokenLetter, foreground: Color = .primary) {
        self.letter = letter
        self.foreground = foreground
    }

    public var body: some View {
        Group {
            if UIImage(named: letter.assetName) != nil {
                Image(letter.assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                GeometricSymbol(letter: letter)
            }
        }
        .foregroundStyle(foreground)
        .accessibilityLabel(Text(letter.upperLatin))
        .accessibilityHint(Text(letter.glyphDescription))
    }
}

// MARK: - Geometric fallbacks (stand in until PDF assets are dropped in)

/// Approximate ritual glyphs so the keyboard is usable without hand-traced art.
struct GeometricSymbol: View {
    let letter: SleepTokenLetter

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.12, dy: size.height * 0.12)
            var path = Path()
            draw(letter: letter, in: rect, path: &path)
            context.stroke(path, with: .foreground, lineWidth: max(1.2, size.width * 0.06))
            // Filled regions for half-diamonds etc.
            if let fill = fillPath(letter: letter, in: rect) {
                context.fill(fill, with: .foreground)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func diamond(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }

    private func draw(letter: SleepTokenLetter, in r: CGRect, path: inout Path) {
        let cx = r.midX, cy = r.midY
        let s = min(r.width, r.height)

        switch letter {
        case .a:
            path.addEllipse(in: CGRect(x: cx - s * 0.28, y: cy - s * 0.38, width: s * 0.56, height: s * 0.56))
            path.addEllipse(in: CGRect(x: cx - s * 0.06, y: cy - s * 0.16, width: s * 0.12, height: s * 0.12))
            path.move(to: CGPoint(x: cx - s * 0.12, y: r.maxY - s * 0.05))
            path.addLine(to: CGPoint(x: cx + s * 0.12, y: r.maxY - s * 0.05))
            path.move(to: CGPoint(x: cx, y: r.maxY - s * 0.18))
            path.addLine(to: CGPoint(x: cx - s * 0.1, y: r.maxY))
            path.move(to: CGPoint(x: cx, y: r.maxY - s * 0.18))
            path.addLine(to: CGPoint(x: cx + s * 0.1, y: r.maxY))
        case .b:
            path.addPath(diamond(in: r))
            path.move(to: CGPoint(x: r.minX + s * 0.15, y: cy))
            path.addLine(to: CGPoint(x: r.maxX - s * 0.15, y: cy))
        case .c, .d, .f, .g, .w, .y:
            path.addPath(diamond(in: r))
            if letter == .g {
                path.addEllipse(in: CGRect(x: cx - s * 0.07, y: cy - s * 0.07, width: s * 0.14, height: s * 0.14))
            }
        case .e:
            path.move(to: CGPoint(x: r.minX, y: cy - s * 0.15))
            path.addLine(to: CGPoint(x: r.maxX, y: cy - s * 0.15))
            path.move(to: CGPoint(x: cx - s * 0.22, y: cy + s * 0.05))
            path.addLine(to: CGPoint(x: cx, y: cy + s * 0.35))
            path.addLine(to: CGPoint(x: cx + s * 0.22, y: cy + s * 0.05))
        case .h:
            path.addPath(diamond(in: r))
            path.move(to: CGPoint(x: cx - s * 0.2, y: cy - s * 0.2))
            path.addLine(to: CGPoint(x: cx + s * 0.2, y: cy + s * 0.2))
            path.move(to: CGPoint(x: cx + s * 0.2, y: cy - s * 0.2))
            path.addLine(to: CGPoint(x: cx - s * 0.2, y: cy + s * 0.2))
            path.addEllipse(in: CGRect(x: cx - s * 0.06, y: cy - s * 0.06, width: s * 0.12, height: s * 0.12))
        case .i:
            path.move(to: CGPoint(x: cx + s * 0.15, y: cy - s * 0.35))
            path.addLine(to: CGPoint(x: cx - s * 0.25, y: cy))
            path.addLine(to: CGPoint(x: cx + s * 0.15, y: cy + s * 0.35))
            path.addEllipse(in: CGRect(x: cx - s * 0.06, y: cy - s * 0.06, width: s * 0.12, height: s * 0.12))
        case .j:
            path.move(to: CGPoint(x: cx - s * 0.15, y: cy - s * 0.35))
            path.addLine(to: CGPoint(x: cx + s * 0.25, y: cy))
            path.addLine(to: CGPoint(x: cx - s * 0.15, y: cy + s * 0.35))
            path.addEllipse(in: CGRect(x: cx - s * 0.28, y: cy - s * 0.06, width: s * 0.12, height: s * 0.12))
        case .k:
            path.move(to: CGPoint(x: cx - s * 0.15, y: cy - s * 0.35))
            path.addLine(to: CGPoint(x: cx + s * 0.25, y: cy))
            path.addLine(to: CGPoint(x: cx - s * 0.15, y: cy + s * 0.35))
            path.move(to: CGPoint(x: cx - s * 0.05, y: cy - s * 0.15))
            path.addLine(to: CGPoint(x: cx + s * 0.15, y: cy + s * 0.15))
            path.move(to: CGPoint(x: cx + s * 0.15, y: cy - s * 0.15))
            path.addLine(to: CGPoint(x: cx - s * 0.05, y: cy + s * 0.15))
            path.addEllipse(in: CGRect(x: cx - s * 0.32, y: cy - s * 0.06, width: s * 0.12, height: s * 0.12))
        case .l:
            path.move(to: CGPoint(x: cx - s * 0.25, y: cy - s * 0.3))
            path.addLine(to: CGPoint(x: cx + s * 0.25, y: cy + s * 0.3))
            path.move(to: CGPoint(x: cx + s * 0.25, y: cy - s * 0.3))
            path.addLine(to: CGPoint(x: cx - s * 0.05, y: cy + s * 0.1))
            path.addEllipse(in: CGRect(x: cx + s * 0.12, y: cy + s * 0.12, width: s * 0.12, height: s * 0.12))
        case .m:
            path.move(to: CGPoint(x: r.minX + s * 0.1, y: r.maxY - s * 0.1))
            path.addLine(to: CGPoint(x: cx, y: r.minY + s * 0.1))
            path.addLine(to: CGPoint(x: r.maxX - s * 0.1, y: r.maxY - s * 0.1))
            path.move(to: CGPoint(x: cx - s * 0.12, y: cy - s * 0.05))
            path.addLine(to: CGPoint(x: cx + s * 0.12, y: cy + s * 0.2))
            path.move(to: CGPoint(x: cx + s * 0.12, y: cy - s * 0.05))
            path.addLine(to: CGPoint(x: cx - s * 0.12, y: cy + s * 0.2))
            path.addEllipse(in: CGRect(x: cx - s * 0.06, y: r.maxY - s * 0.22, width: s * 0.12, height: s * 0.12))
        case .n:
            path.move(to: CGPoint(x: r.minX + s * 0.1, y: r.minY + s * 0.15))
            path.addLine(to: CGPoint(x: cx, y: r.maxY - s * 0.1))
            path.addLine(to: CGPoint(x: r.maxX - s * 0.1, y: r.minY + s * 0.15))
            path.move(to: CGPoint(x: cx - s * 0.12, y: cy - s * 0.05))
            path.addLine(to: CGPoint(x: cx + s * 0.12, y: cy + s * 0.2))
            path.move(to: CGPoint(x: cx + s * 0.12, y: cy - s * 0.05))
            path.addLine(to: CGPoint(x: cx - s * 0.12, y: cy + s * 0.2))
            path.addEllipse(in: CGRect(x: cx - s * 0.06, y: r.minY + s * 0.05, width: s * 0.12, height: s * 0.12))
        case .o:
            path.move(to: CGPoint(x: cx - s * 0.22, y: r.minY + s * 0.1))
            path.addLine(to: CGPoint(x: cx - s * 0.22, y: r.maxY - s * 0.15))
            path.addQuadCurve(to: CGPoint(x: cx - s * 0.05, y: r.maxY - s * 0.15),
                              control: CGPoint(x: cx - s * 0.22, y: r.maxY))
            path.move(to: CGPoint(x: cx + s * 0.05, y: r.minY + s * 0.1))
            path.addLine(to: CGPoint(x: cx + s * 0.05, y: r.maxY - s * 0.15))
            path.addQuadCurve(to: CGPoint(x: cx + s * 0.22, y: r.maxY - s * 0.15),
                              control: CGPoint(x: cx + s * 0.22, y: r.maxY))
            path.move(to: CGPoint(x: cx + s * 0.22, y: r.minY + s * 0.1))
            path.addLine(to: CGPoint(x: cx + s * 0.22, y: r.maxY - s * 0.25))
        case .p:
            for i in 0..<3 {
                let x = cx + CGFloat(i - 1) * s * 0.28
                path.move(to: CGPoint(x: x, y: r.minY + s * 0.08))
                path.addLine(to: CGPoint(x: x, y: r.maxY - s * 0.18))
                path.addQuadCurve(to: CGPoint(x: x + s * 0.12, y: r.maxY - s * 0.18),
                                  control: CGPoint(x: x + s * 0.08, y: r.maxY))
            }
        case .q:
            path.move(to: CGPoint(x: r.minX + s * 0.15, y: r.minY + s * 0.15))
            path.addLine(to: CGPoint(x: r.minX + s * 0.15, y: r.maxY - s * 0.15))
            path.addLine(to: CGPoint(x: r.maxX - s * 0.15, y: r.maxY - s * 0.15))
            path.addLine(to: CGPoint(x: r.maxX - s * 0.15, y: r.minY + s * 0.15))
            path.addEllipse(in: CGRect(x: cx - s * 0.07, y: cy - s * 0.02, width: s * 0.14, height: s * 0.14))
        case .r:
            path.addRect(CGRect(x: r.minX + s * 0.18, y: r.minY + s * 0.18,
                                width: r.width - s * 0.36, height: r.height - s * 0.36))
            path.addEllipse(in: CGRect(x: cx - s * 0.07, y: cy - s * 0.07, width: s * 0.14, height: s * 0.14))
        case .s, .t:
            path.addPath(diamond(in: r))
            path.move(to: CGPoint(x: cx - s * 0.15, y: letter == .s ? r.minY + s * 0.05 : r.maxY - s * 0.05))
            path.addLine(to: CGPoint(x: cx + s * 0.15, y: letter == .s ? r.minY + s * 0.25 : r.maxY - s * 0.25))
            path.move(to: CGPoint(x: cx + s * 0.15, y: letter == .s ? r.minY + s * 0.05 : r.maxY - s * 0.05))
            path.addLine(to: CGPoint(x: cx - s * 0.15, y: letter == .s ? r.minY + s * 0.25 : r.maxY - s * 0.25))
        case .u:
            path.addEllipse(in: r.insetBy(dx: s * 0.08, dy: s * 0.08))
            path.addEllipse(in: r.insetBy(dx: s * 0.22, dy: s * 0.22))
            path.addEllipse(in: CGRect(x: cx - s * 0.06, y: cy - s * 0.06, width: s * 0.12, height: s * 0.12))
        case .v:
            path.addEllipse(in: r.insetBy(dx: s * 0.12, dy: s * 0.18))
            path.addEllipse(in: CGRect(x: cx - s * 0.06, y: cy - s * 0.02, width: s * 0.12, height: s * 0.12))
            path.move(to: CGPoint(x: cx - s * 0.12, y: r.minY + s * 0.08))
            path.addLine(to: CGPoint(x: cx + s * 0.12, y: r.minY + s * 0.22))
            path.move(to: CGPoint(x: cx + s * 0.12, y: r.minY + s * 0.08))
            path.addLine(to: CGPoint(x: cx - s * 0.12, y: r.minY + s * 0.22))
        case .x:
            path.move(to: CGPoint(x: r.minX + s * 0.1, y: cy))
            path.addLine(to: CGPoint(x: r.maxX - s * 0.1, y: cy))
        case .z:
            path.move(to: CGPoint(x: r.minX + s * 0.1, y: cy - s * 0.1))
            path.addLine(to: CGPoint(x: r.maxX - s * 0.1, y: cy - s * 0.1))
            path.move(to: CGPoint(x: cx - s * 0.15, y: cy + s * 0.05))
            path.addLine(to: CGPoint(x: cx, y: cy + s * 0.35))
            path.addLine(to: CGPoint(x: cx + s * 0.15, y: cy + s * 0.05))
            path.move(to: CGPoint(x: cx, y: cy + s * 0.05))
            path.addLine(to: CGPoint(x: cx, y: cy + s * 0.2))
        }
    }

    private func fillPath(letter: SleepTokenLetter, in r: CGRect) -> Path? {
        let d = diamond(in: r)
        switch letter {
        case .c:
            // bottom half
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.closeSubpath()
            return p
        case .d, .t:
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.closeSubpath()
            return p
        case .f:
            var p = Path()
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.closeSubpath()
            return p
        case .y:
            var p = Path()
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.closeSubpath()
            return p
        case .s:
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.closeSubpath()
            return p
        default:
            _ = d
            return nil
        }
    }
}
