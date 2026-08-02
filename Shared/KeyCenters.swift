import CoreGraphics

/// Center point of every QWERTY letter key, in LetterPage's local coordinate space.
///
/// Derived from the SAME KeyboardMetrics arithmetic LetterPage lays out with, never
/// measured from views: the decoder and the screen must share one geometry, and a
/// parity test (KeyCentersTests) holds this file and LetterPage together. The grid
/// layout deliberately has no entry here — glide is QWERTY-only by construction.
public enum KeyCenters {

    public static func qwerty(
        availableWidth: CGFloat,
        keyHeight: CGFloat
    ) -> [SleepTokenLetter: CGPoint] {
        let unit = KeyboardMetrics.keyUnit(availableWidth: availableWidth)
        let step = unit + KeyboardMetrics.keyGap
        var centers: [SleepTokenLetter: CGPoint] = [:]

        for (rowIndex, row) in KeyboardLayout.qwertyRows.enumerated() {
            let y = CGFloat(rowIndex) * (keyHeight + KeyboardMetrics.rowGap) + keyHeight / 2
            let leadingX: CGFloat
            switch rowIndex {
            case 0:
                leadingX = 0
            case 1:
                // Half-key inset that centres 9 keys under the 10-key top row.
                leadingX = KeyboardMetrics.homeRowInset(keyUnit: unit)
            default:
                // Shift and backspace flank this row at equal widths, so the letter
                // block is centered on the page midline by the enclosing VStack.
                let blockWidth = CGFloat(row.count) * unit + CGFloat(row.count - 1) * KeyboardMetrics.keyGap
                leadingX = (availableWidth - blockWidth) / 2
            }
            for (index, letter) in row.enumerated() {
                centers[letter] = CGPoint(x: leadingX + CGFloat(index) * step + unit / 2, y: y)
            }
        }
        return centers
    }
}
