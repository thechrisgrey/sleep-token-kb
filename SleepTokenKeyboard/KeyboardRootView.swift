import SwiftUI
import UIKit

/// Bridge from SwiftUI keyboard chrome to `UITextDocumentProxy`.
struct KeyboardRootView: View {
    let proxy: UITextDocumentProxy
    let onNextKeyboard: () -> Void
    let needsInputModeSwitchKey: Bool
    var onLayoutModeChange: ((LayoutMode) -> Void)? = nil

    @State private var layoutMode: LayoutMode = KeyboardPreferences.layoutMode
    @State private var isShifted = false
    @State private var isCapsLock = false
    @State private var showSymbols = false
    @State private var showLatinHints = KeyboardPreferences.showLatinHints

    private let impact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: 6) {
            topBar
            if showSymbols {
                SymbolsPage(
                    onInsert: insertRaw,
                    onBackspace: deleteBackward
                )
            } else {
                LetterPage(
                    layoutMode: layoutMode,
                    isShifted: isShifted || isCapsLock,
                    showLatinHints: showLatinHints,
                    onLetter: insertLetter,
                    onShift: toggleShift,
                    onBackspace: deleteBackward
                )
            }
            bottomBar
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Color(uiColor: .secondarySystemBackground))
        .onAppear {
            layoutMode = KeyboardPreferences.layoutMode
            showLatinHints = KeyboardPreferences.showLatinHints
            if KeyboardPreferences.hapticsEnabled {
                impact.prepare()
            }
        }
    }

    // MARK: - Bars

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                haptic()
                layoutMode = layoutMode.next
                KeyboardPreferences.layoutMode = layoutMode
                onLayoutModeChange?(layoutMode)
            } label: {
                Label(layoutMode.title, systemImage: layoutMode == .qwerty ? "keyboard" : "square.grid.3x3")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle layout, currently \(layoutMode.accessibilityLabel)")

            Spacer()

            Button {
                haptic()
                showLatinHints.toggle()
                KeyboardPreferences.showLatinHints = showLatinHints
            } label: {
                Image(systemName: showLatinHints ? "textformat.abc" : "textformat.abc.dottedunderline")
                    .font(.body.weight(.medium))
                    .frame(width: 36, height: 32)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(uiColor: .tertiarySystemFill)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showLatinHints ? "Hide Latin hints" : "Show Latin hints")
        }
        .padding(.horizontal, 6)
        .foregroundStyle(Color.primary)
    }

    private var bottomBar: some View {
        HStack(spacing: 6) {
            if needsInputModeSwitchKey {
                KeyChromeButton(systemName: "globe", weight: .medium) {
                    onNextKeyboard()
                }
                .frame(width: 42)
                .accessibilityLabel("Next keyboard")
            }

            KeyChromeButton(title: showSymbols ? "ABC" : "123", weight: .semibold) {
                haptic()
                showSymbols.toggle()
            }
            .frame(width: 52)

            KeyChromeButton(title: "space", weight: .regular) {
                insertRaw(" ")
            }
            .frame(maxWidth: .infinity)

            KeyChromeButton(title: "return", weight: .semibold) {
                insertRaw("\n")
            }
            .frame(width: 74)
        }
        .frame(height: 42)
        .padding(.horizontal, 2)
    }

    // MARK: - Actions

    private func insertLetter(_ letter: SleepTokenLetter) {
        let ch = (isShifted || isCapsLock) ? letter.upperLatin : letter.latin
        insertRaw(ch)
        if isShifted && !isCapsLock {
            isShifted = false
        }
    }

    private func insertRaw(_ text: String) {
        haptic()
        proxy.insertText(text)
    }

    private func deleteBackward() {
        haptic()
        proxy.deleteBackward()
    }

    private func toggleShift() {
        haptic()
        if isShifted {
            // Second tap → caps lock
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

// MARK: - Letter pages

private struct LetterPage: View {
    let layoutMode: LayoutMode
    let isShifted: Bool
    let showLatinHints: Bool
    let onLetter: (SleepTokenLetter) -> Void
    let onShift: () -> Void
    let onBackspace: () -> Void

    private var rows: [[SleepTokenLetter]] {
        layoutMode == .qwerty ? KeyboardLayout.qwertyRows : KeyboardLayout.gridRows
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 5) {
                    if layoutMode == .qwerty && index == 2 {
                        ShiftKeyButton(isActive: isShifted, action: onShift)
                            .frame(width: 44)
                    }

                    ForEach(row) { letter in
                        LetterKeyButton(
                            letter: letter,
                            showLatinHint: showLatinHints,
                            action: { onLetter(letter) }
                        )
                    }

                    if layoutMode == .qwerty && index == 2 {
                        BackspaceKeyButton(action: onBackspace)
                            .frame(width: 44)
                    }
                }
                // Center the shorter middle QWERTY row
                .padding(.horizontal, layoutMode == .qwerty && index == 1 ? 14 : 0)
            }

            if layoutMode == .grid {
                HStack {
                    ShiftKeyButton(isActive: isShifted, action: onShift)
                        .frame(width: 52)
                    Spacer()
                    BackspaceKeyButton(action: onBackspace)
                        .frame(width: 52)
                }
                .frame(height: 40)
                .padding(.horizontal, 4)
            }
        }
    }
}

private struct SymbolsPage: View {
    let onInsert: (String) -> Void
    let onBackspace: () -> Void

    private let rows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'", "#", "%", "*", "+", "="]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { symbol in
                        KeyChromeButton(title: symbol, weight: .medium) {
                            onInsert(symbol)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                BackspaceKeyButton(action: onBackspace)
                    .frame(width: 52, height: 40)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Keys

private struct LetterKeyButton: View {
    let letter: SleepTokenLetter
    let showLatinHint: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                SymbolGlyphView(letter: letter, foreground: .primary)
                    .frame(height: showLatinHint ? 22 : 28)
                    .padding(.top, 4)

                if showLatinHint {
                    Text(letter.upperLatin)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
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
                        .font(.system(size: title.count > 2 ? 14 : 18, weight: weight, design: .rounded))
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
