import SwiftUI
import UIKit

/// Vertical ritual writing, read back in Latin, exported in whichever form the
/// destination app understands.
///
/// Layout: plaque canvas (the runes), translation strip (the Latin reading with live
/// spell check), letter pad. Long words / many columns automatically scale down so the
/// canvas stays in view. Canvas geometry and the export types live in
/// `RuneCanvas.swift` / `RuneExport.swift`.
struct RunePadView: View {
    /// Words separated by spaces; each word is one vertical column.
    @State private var text = ""
    @State private var status: String?
    @State private var statusExpiry: Task<Void, Never>?
    @State private var isExporting = false
    @State private var shareItem: ShareItem?
    @State private var confirmClear = false
    @State private var deleteRepeater: Task<Void, Never>?
    /// `@GestureState` rather than `@State`: SwiftUI resets it on gesture end *and* on
    /// system touch-cancellation, where a drag's `onEnded` never arrives.
    @GestureState private var isPressingDelete = false
    /// One checker for the view's lifetime. The read-back is recomputed during `body`,
    /// so this must outlive a single evaluation to be worth anything.
    @State private var spellChecker = SpellChecker()

    @Environment(\.displayScale) private var displayScale

    private let preferredRuneSize: CGFloat = 32
    private let rows: [[SleepTokenLetter]] = KeyboardLayout.qwertyRows

    var body: some View {
        // No spacer: the canvas absorbs all free height, so the letter pad sits
        // down by the home indicator like a real keyboard.
        VStack(spacing: 14) {
            canvas
            translationStrip
            letterPad
        }
        .padding(16)
        .readableColumn()
        .background(RitualBackground())
        .navigationTitle("Rune Pad")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { _ = RuneFont.registerIfNeeded() }
        .toolbar {
            // Jerry roosts beside the back button, where nobody looks.
            ToolbarItem(placement: .topBarLeading) {
                HiddenJerry(spot: .runeToolbar, height: 12)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Clear", role: .destructive) { confirmClear = true }
                    .disabled(text.isEmpty)

                exportMenu
            }
        }
        .confirmationDialog(
            "Clear the canvas?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                statusExpiry?.cancel()
                text = ""
                status = nil
            }
            Button("Keep composing", role: .cancel) {}
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url]) { completed in
                // The sheet is done with the file either way; confirm only success.
                try? FileManager.default.removeItem(at: item.url)
                if completed {
                    setStatus("Image shared.")
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            if text.isEmpty {
                emptyState
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                let metrics = CanvasMetrics.fitted(
                    columns: columns,
                    in: geo.size,
                    preferredRuneSize: preferredRuneSize
                )
                VerticalRuneColumnsView(
                    columns: columns,
                    runeSize: metrics.runeSize,
                    columnSpacing: metrics.columnSpacing,
                    runeSpacing: metrics.runeSpacing,
                    ink: Theme.ink,
                    showChrome: true
                )
                .padding(metrics.padding)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .animation(.easeOut(duration: 0.15), value: text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 190)
        // Overflow (more columns than even 8pt runes can fit) degrades inside the
        // plaque instead of drawing across its border.
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // One element: VoiceOver hears the words being written, not a stream of
        // per-glyph letters and shape hints.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rune canvas")
        .accessibilityValue(
            text.isEmpty
                ? "Empty. Tap the keys below to compose."
                : latinWords.joined(separator: " ")
        )
        // Translucent in Arcadia so the petals falling down the background
        // stay visible behind the composed runes.
        .ritualCard(padding: 0, fill: Theme.canvasSurface)
        // Jerry wades in the plaque's lower-right shallows.
        .overlay(alignment: .bottomTrailing) {
            HiddenJerry(spot: .runeCanvas, height: 13)
                .padding(4)
        }
        // Status rides the canvas card instead of stacking below the pad, so its
        // appearance never nudges the pad away from the bottom edge.
        .overlay(alignment: .bottomLeading) {
            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Theme.field.opacity(0.85))
                    )
                    .padding(10)
                    .transition(.opacity)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            RuneWordRow(word: "sleep token", glyphSize: 13, spacing: 9, color: Theme.inkFaint)
            Text("Tap the keys below. Runes stack top to bottom;\nspace starts a new column.")
                .font(.caption)
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: - Translation + spell check

    /// Latin reading of each column, lowercase for the checker.
    private var latinWords: [String] {
        columns
            .filter { !$0.isEmpty }
            .map { SleepTokenLetter.latinTranslation(of: $0) }
    }

    /// Words the system dictionary does not recognise. The rules — which columns count
    /// as finished, and how proper nouns pass — live in `SpellChecker`, along with the
    /// one `UITextChecker` they share. This is reached from `body`, so constructing a
    /// checker here (as it used to) meant paying for one on every keystroke.
    private func misspelledWords(in words: [String]) -> Set<String> {
        spellChecker.misspelled(
            in: SpellChecker.completedWords(words, textEndsWithSpace: text.hasSuffix(" "))
        )
    }

    @ViewBuilder
    private var translationStrip: some View {
        let words = latinWords
        if !words.isEmpty {
            let flagged = misspelledWords(in: words)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("READS")
                        .font(Theme.overline())
                        .tracking(2.2)
                        .foregroundStyle(Theme.inkDim)
                    Self.translationText(words: words, flagged: flagged)
                        .font(Theme.display(.callout, weight: .medium))
                        .kerning(1.4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !flagged.isEmpty {
                    Text("Underlined words are not in the dictionary.")
                        .font(.caption2)
                        .foregroundStyle(Theme.caution.opacity(0.8))
                }
            }
            .ritualCard(padding: 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reads \(words.joined(separator: " "))")
            .accessibilityValue(
                flagged.isEmpty
                    ? ""
                    : "\(flagged.sorted().joined(separator: ", ")) not in the dictionary"
            )
        }
    }

    /// Pure: both inputs explicit, so the styling logic is testable in isolation.
    private static func translationText(words: [String], flagged: Set<String>) -> Text {
        var combined = Text("")
        for (index, word) in words.enumerated() {
            var piece = Text(word.uppercased())
            if flagged.contains(word) {
                piece = piece
                    .foregroundColor(Theme.caution)
                    .underline(true, color: Theme.caution)
            } else {
                piece = piece.foregroundColor(Theme.ink)
            }
            combined = index == 0 ? piece : combined + Text("  ") + piece
        }
        return combined
    }

    // MARK: - Columns model

    private var columns: [String] {
        if text.isEmpty { return [""] }
        if text.hasSuffix(" ") {
            return String(text.dropLast()).components(separatedBy: " ") + [""]
        }
        return text.components(separatedBy: " ")
    }

    // MARK: - Pad

    private var letterPad: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 5) {
                    ForEach(row) { letter in
                        Button { text.append(letter.exactRuneString) } label: {
                            VStack(spacing: 2) {
                                SymbolGlyphView(letter: letter, foreground: Theme.ink)
                                    .frame(height: 20)
                                    .accessibilityHidden(true)
                                Text(letter.upperLatin)
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Theme.inkFaint)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.surfaceHigh)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(letter.upperLatin)
                    }
                }
                .padding(.horizontal, index == 1 ? 12 : 0)
            }

            HStack(spacing: 8) {
                Button(action: startNewColumn) {
                    Text("SPACE · NEW COLUMN")
                        .font(Theme.overline())
                        .tracking(1.8)
                        .foregroundStyle(Theme.inkDim)
                        .frame(maxWidth: .infinity)
                        // minHeight, not height: 44pt is the platform floor, and the
                        // label scales with Dynamic Type now.
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Space, starts a new column")

                // Delete auto-repeats while held, like the system keyboard's key.
                // Deliberately not a Button: a Button fires on release, so pairing one
                // with a press-tracking gesture ends every hold with an extra deletion.
                // The zero-distance drag owns the whole press — one delete on
                // touch-down, repeats from the task, nothing on release.
                Image(systemName: "delete.left")
                    .foregroundStyle(Theme.ink)
                    .frame(width: 56, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                    // Stands in for the pressed dim `.buttonStyle(.plain)` used to give.
                    .opacity(isPressingDelete ? 0.55 : 1)
                    // The glyph does not fill the keycap, so without this its corners
                    // are visually part of the key but not touchable.
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($isPressingDelete) { _, pressing, _ in
                                pressing = true
                            }
                    )
                    .onChange(of: isPressingDelete) { _, pressing in
                        if pressing {
                            deleteBackward()
                            startDeleteRepeat()
                        } else {
                            stopDeleteRepeat()
                        }
                    }
                    // The view can leave the screen mid-hold (back navigation, a
                    // sheet), which never resets the gesture.
                    .onDisappear(perform: stopDeleteRepeat)
                    // No Button any more, so activation is restored explicitly:
                    // VoiceOver and Switch Control activate deletes a single rune.
                    .accessibilityLabel("Delete")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { deleteBackward() }
            }
        }
        .ritualCard(padding: 10)
    }

    // MARK: - Export

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var exportMenu: some View {
        Menu {
            Section("Copy image") {
                ForEach(RuneExportStyle.allCases, id: \.self) { style in
                    Button {
                        Task { await copyImage(style: style) }
                    } label: {
                        Label(style.menuTitle, systemImage: style.systemImage)
                    }
                }
            }
            Button {
                Task { await shareImage() }
            } label: {
                Label("Share as image", systemImage: "square.and.arrow.up")
            }
            Button {
                copyLatinText()
            } label: {
                Label("Copy as Latin text", systemImage: "textformat")
            }
        } label: {
            if isExporting {
                ProgressView()
                    .accessibilityLabel("Exporting")
            } else {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
        .disabled(!hasContent || isExporting)
    }

    // MARK: - Actions

    private func startNewColumn() {
        guard !text.isEmpty, !text.hasSuffix(" ") else { return }
        text.append(" ")
    }

    private func deleteBackward() {
        guard !text.isEmpty else { return }
        text.removeLast()
    }

    private func startDeleteRepeat() {
        deleteRepeater?.cancel()
        deleteRepeater = Task { @MainActor in
            // The gap that separates a tap from a hold. Cancelling during it leaves
            // the single delete already fired on touch-down and nothing more.
            try? await Task.sleep(for: .seconds(KeyRepeat.initialDelay))

            var fired = 1
            while !Task.isCancelled {
                deleteBackward()
                try? await Task.sleep(for: .seconds(KeyRepeat.interval(forRepeat: fired)))
                fired += 1
            }
        }
    }

    private func stopDeleteRepeat() {
        deleteRepeater?.cancel()
        deleteRepeater = nil
    }

    /// One path for all export feedback: fades in (the transition is otherwise
    /// inert), announces to VoiceOver, and clears itself after a few seconds so the
    /// capsule never squats on the canvas forever.
    private func setStatus(_ message: String) {
        statusExpiry?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { status = message }
        AccessibilityNotification.Announcement(message).post()
        statusExpiry = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) { status = nil }
        }
    }

    private func copyLatinText() {
        UIPasteboard.general.string = latinWords.joined(separator: " ")
        setStatus("Latin text copied. Paste it anywhere to spell check or search.")
    }

    @MainActor
    private func copyImage(style: RuneExportStyle) async {
        guard let image = await renderImage(style: style) else {
            setStatus("Could not render image. Try again.")
            return
        }
        if let png = image.pngData() {
            // The explicit public.png representation is the point of the
            // transparent styles — nothing may replace this item afterwards.
            UIPasteboard.general.setItems([[
                "public.png": png,
                "com.apple.uikit.image": image
            ]], options: [:])
        } else {
            UIPasteboard.general.image = image
        }
        setStatus(style.copiedMessage)
    }

    @MainActor
    private func shareImage() async {
        guard let image = await renderImage(style: .plaque),
              let png = image.pngData() else {
            setStatus("Could not render image. Try again.")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sleep-token-runes.png")
        do {
            try png.write(to: url, options: .atomic)
            shareItem = ShareItem(url: url)
        } catch {
            setStatus("Could not prepare the share file. Try again.")
        }
    }

    @MainActor
    private func renderImage(style: RuneExportStyle) async -> UIImage? {
        isExporting = true
        defer { isExporting = false }

        _ = RuneFont.registerIfNeeded()

        let exportColumns = columns.filter { !$0.isEmpty }
        // Export at a comfortable resolution (not the on-screen shrunk size).
        let exportMetrics = CanvasMetrics.forExport(
            columns: exportColumns,
            preferredRuneSize: preferredRuneSize
        )

        let runes = VerticalRuneColumnsView(
            columns: exportColumns,
            runeSize: exportMetrics.runeSize,
            columnSpacing: exportMetrics.columnSpacing,
            runeSpacing: exportMetrics.runeSpacing,
            ink: style.ink,
            showChrome: false
        )

        let content = Group {
            switch style {
            case .lightInk, .darkInk:
                runes.padding(24)
            case .plaque:
                runes
                    .padding(36)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(RuneExportStyle.plaqueFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .padding(4)
            }
        }

        let renderer = ImageRenderer(content: content)
        // UIScreen.main is deprecated in iOS 26; displayScale is the SwiftUI-native
        // equivalent and correctly follows the scene this view is actually in.
        renderer.scale = displayScale
        renderer.isOpaque = false

        // One turn of the run loop so the isExporting ProgressView can paint
        // before the render occupies the main actor.
        await Task.yield()

        return renderer.uiImage
    }
}

#Preview {
    NavigationStack {
        RunePadView()
    }
    .preferredColorScheme(.dark)
    .tint(Theme.gold)
}
