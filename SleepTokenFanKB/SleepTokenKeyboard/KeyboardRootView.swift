import SwiftUI
import UIKit

/// Simple fan keyboard: ritual or ABC keycaps, always types normal English.
/// For actual rune *text*, open Rune Pad in the host app and copy as image.
struct KeyboardRootView: View {
    let proxy: UITextDocumentProxy
    let onNextKeyboard: () -> Void
    let needsInputModeSwitchKey: Bool
    var onNeedsHeightUpdate: (() -> Void)? = nil

    @State private var layoutMode: LayoutMode = KeyboardPreferences.layoutMode
    @State private var keyFaceStyle: KeyFaceStyle = KeyboardPreferences.keyFaceStyle
    @State private var isShifted = false
    @State private var isCapsLock = false
    @State private var showSymbols = false
    @State private var showLatinHints = KeyboardPreferences.showLatinHints

    private let impact = UIImpactFeedbackGenerator(style: .light)

    private var keyHeight: CGFloat {
        (showLatinHints && keyFaceStyle == .runeArt) ? 44 : 40
    }
    private let rowGap: CGFloat = 6
    private let bottomBarHeight: CGFloat = 42

    var body: some View {
        VStack(spacing: rowGap) {
            if showSymbols {
                SymbolsPage(keyHeight: keyHeight, rowGap: rowGap, onInsert: insertRaw, onBackspace: handleBackspace)
            } else {
                LetterPage(
                    layoutMode: layoutMode,
                    keyFaceStyle: keyFaceStyle,
                    isShifted: isShifted || isCapsLock,
                    showLatinHints: showLatinHints,
                    keyHeight: keyHeight,
                    rowGap: rowGap,
                    onLetter: insertLetter,
                    onShift: toggleShift,
                    onBackspace: handleBackspace
                )
            }

            bottomBar
                .frame(height: bottomBarHeight)
        }
        .padding(.horizontal, 3)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color(uiColor: .secondarySystemBackground))
        .onAppear {
            layoutMode = KeyboardPreferences.layoutMode
            keyFaceStyle = KeyboardPreferences.keyFaceStyle
            showLatinHints = KeyboardPreferences.showLatinHints
            if KeyboardPreferences.hapticsEnabled {
                impact.prepare()
            }
        }
    }

    // MARK: - Bottom chrome

    private var bottomBar: some View {
        HStack(spacing: 4) {
            if needsInputModeSwitchKey {
                KeyChromeButton(systemName: "globe", weight: .medium, action: onNextKeyboard)
                    .frame(width: 34)
                    .accessibilityLabel("Next keyboard")
            }

            KeyChromeButton(
                title: layoutMode == .qwerty ? "A–Z" : "QWRTY",
                weight: .semibold
            ) {
                haptic()
                layoutMode = layoutMode.next
                KeyboardPreferences.layoutMode = layoutMode
                onNeedsHeightUpdate?()
            }
            .frame(width: 50)
            .accessibilityLabel("Switch layout")

            // Rune art keys ↔ plain ABC keys (text is always English either way)
            KeyChromeButton(
                title: keyFaceStyle == .runeArt ? "ABC" : "Art",
                weight: .semibold
            ) {
                haptic()
                keyFaceStyle = keyFaceStyle.next
                KeyboardPreferences.keyFaceStyle = keyFaceStyle
            }
            .frame(width: 42)
            .accessibilityLabel("Key style \(keyFaceStyle.title)")

            KeyChromeButton(title: showSymbols ? "ABC" : "123", weight: .semibold) {
                haptic()
                showSymbols.toggle()
            }
            .frame(width: 42)

            KeyChromeButton(title: "space", weight: .regular) {
                insertRaw(" ")
            }
            .frame(maxWidth: .infinity)

            KeyChromeButton(title: "return", weight: .semibold) {
                insertRaw("\n")
            }
            .frame(width: 60)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Actions

    private func insertLetter(_ letter: SleepTokenLetter) {
        let shifted = isShifted || isCapsLock
        insertRaw(letter.englishInsert(shifted: shifted))
        if isShifted && !isCapsLock {
            isShifted = false
        }
    }

    private func insertRaw(_ text: String) {
        haptic()
        proxy.insertText(text)
    }

    private func handleBackspace() {
        haptic()
        proxy.deleteBackward()
    }

    private func toggleShift() {
        haptic()
        if isShifted {
            if isCapsLock {
                isCapsLock = false
                isShifted = false
            } else {
                isCapsLock = true
            }
        } else {
            isShifted = true
            isCapsLock = false
        }
    }

    private func haptic() {
        guard KeyboardPreferences.hapticsEnabled else { return }
        impact.impactOccurred(intensity: 0.7)
    }
}

// MARK: - Pages

private struct LetterPage: View {
    let layoutMode: LayoutMode
    let keyFaceStyle: KeyFaceStyle
    let isShifted: Bool
    let showLatinHints: Bool
    let keyHeight: CGFloat
    let rowGap: CGFloat
    let onLetter: (SleepTokenLetter) -> Void
    let onShift: () -> Void
    let onBackspace: () -> Void

    private var rows: [[SleepTokenLetter]] {
        layoutMode == .qwerty ? KeyboardLayout.qwertyRows : KeyboardLayout.gridRows
    }

    var body: some View {
        VStack(spacing: rowGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 5) {
                    if layoutMode == .qwerty && index == 2 {
                        ShiftKeyButton(isActive: isShifted, action: onShift)
                            .frame(width: 42, height: keyHeight)
                    }

                    ForEach(row) { letter in
                        LetterKeyButton(
                            letter: letter,
                            keyFaceStyle: keyFaceStyle,
                            showLatinHint: showLatinHints && keyFaceStyle == .runeArt,
                            keyHeight: keyHeight,
                            action: { onLetter(letter) }
                        )
                    }

                    if layoutMode == .qwerty && index == 2 {
                        BackspaceKeyButton(action: onBackspace)
                            .frame(width: 42, height: keyHeight)
                    }
                }
                .padding(.horizontal, layoutMode == .qwerty && index == 1 ? 12 : 0)
            }

            if layoutMode == .grid {
                HStack {
                    ShiftKeyButton(isActive: isShifted, action: onShift)
                        .frame(width: 48, height: keyHeight)
                    Spacer(minLength: 0)
                    BackspaceKeyButton(action: onBackspace)
                        .frame(width: 48, height: keyHeight)
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct SymbolsPage: View {
    let keyHeight: CGFloat
    let rowGap: CGFloat
    let onInsert: (String) -> Void
    let onBackspace: () -> Void

    private let rows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'", "#", "%", "*", "+", "="]
    ]

    var body: some View {
        VStack(spacing: rowGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { symbol in
                        KeyChromeButton(title: symbol, weight: .medium) {
                            onInsert(symbol)
                        }
                        .frame(height: keyHeight)
                    }
                }
            }
            HStack {
                Spacer(minLength: 0)
                BackspaceKeyButton(action: onBackspace)
                    .frame(width: 48, height: keyHeight)
            }
        }
    }
}

// MARK: - Keys

private struct LetterKeyButton: View {
    let letter: SleepTokenLetter
    let keyFaceStyle: KeyFaceStyle
    let showLatinHint: Bool
    let keyHeight: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch keyFaceStyle {
                case .runeArt:
                    VStack(spacing: 1) {
                        SymbolGlyphView(letter: letter, foreground: .primary)
                            .frame(height: showLatinHint ? 22 : 28)
                            .padding(.top, 4)

                        if showLatinHint {
                            Text(letter.upperLatin)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 2)
                        } else {
                            Spacer(minLength: 0)
                        }
                    }
                case .letters:
                    Text(letter.upperLatin)
                        .font(.system(size: max(17, keyHeight * 0.42), weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: keyHeight)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.18), radius: 0.5, y: 1)
            )
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(letter.upperLatin)
    }
}

private struct ShiftKeyButton: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "shift.fill" : "shift")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive
                              ? Color(uiColor: .systemGray2)
                              : Color(uiColor: .systemGray4))
                )
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(isActive ? "Shift on" : "Shift")
    }
}

private struct BackspaceKeyButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "delete.left")
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(uiColor: .systemGray4))
                )
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel("Delete")
    }
}

private struct KeyChromeButton: View {
    var title: String? = nil
    var systemName: String? = nil
    var weight: Font.Weight = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.body.weight(weight))
                } else if let title {
                    Text(title)
                        .font(.system(size: title.count > 3 ? 11 : (title.count > 2 ? 12 : 15), weight: weight, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(uiColor: .systemGray4))
            )
        }
        .buttonStyle(KeyPressStyle())
    }
}

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
