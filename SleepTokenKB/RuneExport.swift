import SwiftUI
import UIKit

/// Export machinery for the Rune Pad, split out so `RunePadView.swift` holds only
/// the composing view. Owns every per-style fact — ink, menu title, symbol, and
/// status copy — so adding a style is one enum case, not a hunt across the view.

/// The three image forms. Two transparent PNGs (one per destination background) and a
/// plaque that is legible on any background because it brings its own.
enum RuneExportStyle: CaseIterable {
    case lightInk
    case darkInk
    case plaque

    static let plaqueFill = Color(red: 0.062, green: 0.058, blue: 0.066)

    var ink: Color {
        switch self {
        case .lightInk: Color(white: 0.93)
        case .darkInk: Color(white: 0.08)
        case .plaque: Theme.ink
        }
    }

    var menuTitle: String {
        switch self {
        case .lightInk: "For dark backgrounds"
        case .darkInk: "For light backgrounds"
        case .plaque: "On plaque"
        }
    }

    var systemImage: String {
        switch self {
        case .lightInk: "moon"
        case .darkInk: "sun.max"
        case .plaque: "rectangle.fill"
        }
    }

    var copiedMessage: String {
        switch self {
        case .lightInk: "Copied: transparent, light ink. Paste over dark backgrounds."
        case .darkInk: "Copied: transparent, dark ink. Paste over light backgrounds."
        case .plaque: "Copied: plaque image. Legible on any background."
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    /// Called once when the sheet is dismissed; `true` when an activity completed,
    /// `false` on cancel. Lets the caller clean up the temp file and confirm.
    var onComplete: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let onComplete {
            controller.completionWithItemsHandler = { _, completed, _, _ in
                onComplete(completed)
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
