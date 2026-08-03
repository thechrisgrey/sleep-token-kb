import SwiftUI
import UIKit

/// Simple fan keyboard: ritual or ABC keycaps, always types normal English.
/// For actual rune *text*, open Rune Pad in the host app and copy as image.
///
/// Text entry is owned by the controller and reached through closures, so the proxy is
/// read live at the moment of the keystroke rather than snapshotted into this struct.
struct KeyboardRootView: View {
    let onInsert: (String) -> Void
    let onDeleteBackward: () -> Void
    let onNextKeyboard: () -> Void
    let needsInputModeSwitchKey: Bool
    /// Bumped by the controller when focus moves to a different host field. Per-field
    /// session state — shift provenance, the double-space window — resets on change.
    let fieldGeneration: Int
    /// Bumped on every host text change (including after this keyboard's own edits, once
    /// the proxy context has settled); shift is re-derived on change. Manual states
    /// survive by rule, so the re-derivation can only correct, never clobber.
    let hostTextGeneration: Int
    /// Contact names and text replacements, merged into the glide lexicon on appear.
    let supplementaryWords: [String]
    /// Live reads of the field being edited: what precedes the cursor, how it wants text
    /// capitalised, what its return key means, and whether Full Access was granted.
    let host: HostField
    /// Reports the page and layout mode whenever something that changes the required
    /// height changes, so the container re-reserves space from the same inputs the
    /// content lays itself out with -- one value, one channel.
    var onHeightInputsChanged: ((KeyboardMetrics.HeightInputs) -> Void)? = nil

    // Preferences are deliberately declared with inert defaults and loaded in exactly one
    // place — `loadPreferences()`, called from `prepareForAppearance()` on appear.
    // Previously they were read both here and in onAppear, with neither identifiable
    // as authoritative.
    @State private var layoutMode: LayoutMode = .qwerty
    @State private var keyFaceStyle: KeyFaceStyle = .runeArt
    @State private var hapticsEnabled = true
    @State private var glideEnabled = true

    /// Shift plus its provenance. The pairing matters: an auto-armed shift re-derives
    /// from context on every call while a manual one is preserved, which is what breaks
    /// the ratchet the 2026-07-31 audit found (delete back into a word, shift stayed up).
    @State private var autoShift = AutoShift()
    @State private var page: KeyboardMetrics.Page = .letters

    /// Whether a character has been typed since this visit to the symbol planes began.
    /// Stock arms the space bar's return to letters on the first keystroke of a visit, not
    /// on arrival — `123 space` stays on 123 so a "meet me at " keeps the digits one tap
    /// away, while `123 5 space` goes back. Every deliberate page change clears it through
    /// `setPage`; the 123 <-> #+= toggle deliberately does not, because stock counts the
    /// two symbol planes as one visit. See `PageAfterSpace`.
    @State private var typedOnSymbolPage = false

    /// Bookkeeping for the double-space shortcut. A reference type held in `@State` on
    /// purpose, twice over: the reference never changes, so recording a timestamp does
    /// not invalidate the view tree (nothing renders it — the old `Date?` in `@State`
    /// re-diffed the whole keyboard per space press), while `@State` keeps the instance
    /// stable across the per-keystroke rootView reassignments the controller performs.
    @State private var spaceTracker = SpaceTracker()

    /// Whole-word backspace bookkeeping for the last glide. Reference type in
    /// `@State` for the same reason `spaceTracker` is: nothing renders it.
    @State private var glideUndo = GlideUndo()
    /// True while the suggestion bar is showing a glide's alternates: the echo of
    /// the glide commit must not overwrite them with spell candidates.
    @State private var showsGlideAlternates = false

    /// Double-tap-shift-for-caps-lock, the gesture an iPhone thumb already knows. The
    /// three-tap cycle still works; this is a shortcut into the same state.
    @State private var capsLockTap = CapsLockTap()

    /// Emoji page session state. Recents are persisted; the selected tab is not, because
    /// stock reopens on recents too.
    @State private var emojiCategory: EmojiCategory = .recents
    @State private var emojiRecents: [String] = []

    /// Shown when the emoji key is long-pressed: the two switches that used to sit on the
    /// bottom bar and cost it a stock-width space key.
    @State private var showsKeyboardOptions = false

    /// Spelling correction. The engine holds one `UITextChecker` and memoises per word,
    /// so it must outlive a single body evaluation — this is reached on every keystroke.
    @State private var suggestionEngine = SuggestionEngine()
    @State private var suggestions = SuggestionSet(literal: "", candidates: [])

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Scaled within the keyboard's fixed height budget, clamped at the root so the
    /// extension cannot grow unboundedly.
    @ScaledMetric(relativeTo: .caption2) private var hintSize: CGFloat = 9
    @ScaledMetric(relativeTo: .body) private var letterFaceSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var symbolFaceSize: CGFloat = 16

    /// One generator for the life of the extension. As an instance property it was
    /// re-allocated with every root view, so the object `prepare()` warmed was discarded
    /// before it ever fired.
    private static let impact = UIImpactFeedbackGenerator(style: .light)

    private var isCompact: Bool { verticalSizeClass == .compact }

    /// Page-aware, and it has to be: `pageHeight` budgets symbol and emoji rows at the
    /// base height because those cells never carry a Latin hint. Sizing the rows from the
    /// key face while the page was budgeted from the base would overflow the page by 12pt
    /// whenever the hinted face was selected.
    private var keyHeight: CGFloat {
        KeyboardMetrics.keyHeight(page: page, style: keyFaceStyle, compact: isCompact)
    }

    private var pageHeight: CGFloat {
        KeyboardMetrics.pageHeight(
            page: page,
            mode: layoutMode,
            style: keyFaceStyle,
            compact: isCompact
        )
    }

    var body: some View {
        VStack(spacing: KeyboardMetrics.rowGap) {
            SuggestionBar(
                suggestions: suggestions,
                onKeepLiteral: keepTypedWord,
                onAccept: acceptSuggestion
            )
            .frame(height: KeyboardMetrics.suggestionBarHeight(compact: isCompact))

            switch page {
            case .symbols, .symbolsAlt:
                SymbolsPage(
                    rows: page == .symbols
                        ? KeyboardLayout.symbolRows
                        : KeyboardLayout.symbolAltRows,
                    switchTitle: page == .symbols ? "#+=" : "123",
                    keyHeight: keyHeight,
                    faceSize: symbolFaceSize,
                    // Digits and punctuation move the cursor like any other insert, so
                    // they re-derive too — this was the one mutation path that skipped
                    // it and left shift stale on the 123 page.
                    onInsert: {
                        insert($0)
                        // The keystroke that arms the space bar's return to letters.
                        typedOnSymbolPage = true
                        applyAutocapitalization()
                    },
                    onSwitchPage: {
                        haptic()
                        // Not `setPage`: stock counts 123 and #+= as one visit, so a digit
                        // typed on 123 still arms the space bar over on #+=.
                        page = (page == .symbols) ? .symbolsAlt : .symbols
                    },
                    onBackspace: { deleteBackward(isRepeat: $0) }
                )
                .frame(height: pageHeight)
            case .emoji:
                EmojiPage(
                    category: $emojiCategory,
                    recents: emojiRecents,
                    cellHeight: keyHeight,
                    onInsert: insertEmoji,
                    onBackspace: { deleteBackward(isRepeat: $0) }
                )
                .frame(height: pageHeight)
            case .letters:
                LetterPage(
                    layoutMode: layoutMode,
                    keyFaceStyle: keyFaceStyle,
                    shift: autoShift.state,
                    keyHeight: keyHeight,
                    hintSize: hintSize,
                    faceSize: letterFaceSize,
                    glideEnabled: glideEnabled,
                    onLetter: insertLetter,
                    onShift: toggleShift,
                    onBackspace: { deleteBackward(isRepeat: $0) },
                    onGlide: handleGlide
                )
                .frame(height: pageHeight)
            }

            bottomBar
                .frame(height: KeyboardMetrics.bottomBarHeight(compact: isCompact))
        }
        .padding(.horizontal, KeyboardMetrics.edgeInset)
        .padding(.top, KeyboardMetrics.topPadding)
        .padding(.bottom, KeyboardMetrics.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(KeyPalette.field)
        // Rendered inside the input view rather than as a popover or sheet: a keyboard
        // extension has no window of its own to present into, and system presentation
        // from an input view is where keyboards go to hang.
        .overlay {
            if showsKeyboardOptions { keyboardOptionsPanel }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onAppear(perform: prepareForAppearance)
        .onChange(of: fieldGeneration) {
            // A different field: the old field's shift provenance and double-space
            // window are meaningless here. Start clean and derive for the new field.
            autoShift = AutoShift()
            spaceTracker.interrupt()
            glideUndo.interrupt()
            capsLockTap.interrupt()
            typedOnSymbolPage = false
            applyAutocapitalization()
            refreshSuggestions()
        }
        .onChange(of: hostTextGeneration) {
            // A change this keyboard did not cause -- a cursor jump, a host-side clear,
            // a same-trait field switch -- breaks double-space consecutiveness; the echo
            // of our own keystroke passes through the tracker silently.
            spaceTracker.hostTextDidChange()
            glideUndo.hostTextDidChange()
            applyAutocapitalization()
            if showsGlideAlternates {
                // The echo of the glide commit: keep the alternates one round.
                showsGlideAlternates = false
            } else {
                refreshSuggestions()
            }
        }
    }

    // MARK: - Bottom chrome
    //
    // One convention across all three switch keys: the title names the DESTINATION, and
    // the accessibility label reads "Switch to <destination>". No two titles can collide
    // — the style key names a style ("Rune"/"Aa"), the page key names an alphabet.

    private var bottomBar: some View {
        HStack(spacing: KeyboardMetrics.keyGap) {
            // Stock puts the page key at the far left; ours used to sit fourth, behind
            // two switches stock has no equivalent for. Those now live behind a long
            // press on the emoji key, which is what buys the space bar its stock width.
            ChromeKeyButton(
                content: .text(page == .letters ? "123" : "ABC"),
                fontSize: 14,
                weight: .semibold,
                label: page == .letters ? "Switch to numbers" : "Switch to letters"
            ) {
                haptic()
                setPage(page == .letters ? .symbols : .letters)
            }
            .frame(width: KeyboardMetrics.functionKeyWidth)

            if needsInputModeSwitchKey {
                // UIKit, not a SwiftUI Button: `handleInputModeList(from:with:)` needs
                // both the originating view and the UIEvent, and only a UIControl action
                // hands us those. Tap still advances; long press opens the picker, which
                // is the stock gesture and the only supported route to Apple's Emoji
                // keyboard for a third-party extension.
                GlobeKey(onTap: onNextKeyboard)
                    .frame(width: 38)
            }

            ChromeKeyButton(
                content: .symbol(page == .emoji ? "keyboard" : "face.smiling"),
                weight: .medium,
                label: page == .emoji ? "Switch to letters" : "Emoji",
                fill: page == .emoji ? KeyPalette.active : KeyPalette.function
            ) {
                haptic()
                setPage(page == .emoji ? .letters : .emoji)
            }
            .frame(width: 38)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                    haptic()
                    showsKeyboardOptions = true
                }
            )
            .accessibilityHint("Double tap and hold for layout and key face")

            // The space bar is a primary key, so it takes the primary keycap fill.
            ChromeKeyButton(
                content: .text("space"),
                fontSize: 14,
                weight: .regular,
                label: "Space",
                fill: KeyPalette.keycap,
                isTypingKey: true
            ) {
                insertSpace()
            }
            .frame(maxWidth: .infinity)

            // The cap names the host field's action -- Search, Send, Done -- rather
            // than always reading "return", and honours enablesReturnKeyAutomatically
            // the way the system keyboard does: disabled until the field has text.
            // The controller rebuilds this view on every host text change, so both
            // stay current. One read serves the cap and the spoken label alike.
            let returnKey = host.returnKeyType()
            ChromeKeyButton(
                content: .text(ReturnKeyTitle.title(for: returnKey)),
                fontSize: 13,
                weight: .semibold,
                label: ReturnKeyTitle.accessibilityLabel(for: returnKey),
                isTypingKey: true,
                enabled: host.returnKeyEnabled()
            ) {
                insert("\n")
                applyAutocapitalization()
            }
            .frame(width: 64)
        }
    }

    /// Layout and key face, reachable by long-pressing the emoji key. Both are still in
    /// the host app's settings; this is the in-keyboard shortcut they used to have as two
    /// permanent chrome keys.
    private var keyboardOptionsPanel: some View {
        ZStack {
            KeyPalette.field.opacity(0.96)
                .contentShape(Rectangle())
                .onTapGesture { showsKeyboardOptions = false }

            VStack(spacing: 10) {
                optionRow(
                    title: "Layout",
                    options: LayoutMode.allCases.map { ($0.shortTitle, $0 == layoutMode) }
                ) { index in
                    layoutMode = LayoutMode.allCases[index]
                    KeyboardPreferences.layoutMode = layoutMode
                    onHeightInputsChanged?(.init(page: page, mode: layoutMode))
                }

                optionRow(
                    title: "Key face",
                    options: KeyFaceStyle.allCases.map { ($0.shortTitle, $0 == keyFaceStyle) }
                ) { index in
                    keyFaceStyle = KeyFaceStyle.allCases[index]
                    KeyboardPreferences.keyFaceStyle = keyFaceStyle
                    onHeightInputsChanged?(.init(page: page, mode: layoutMode))
                }

                Button("Done") { showsKeyboardOptions = false }
                    .font(.footnote.weight(.semibold))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 12)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func optionRow(
        title: String,
        options: [(String, Bool)],
        select: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: KeyboardMetrics.keyGap) {
                ForEach(options.indices, id: \.self) { index in
                    let (label, isSelected) = options[index]
                    Button {
                        haptic()
                        select(index)
                    } label: {
                        Text(label)
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: KeyboardMetrics.functionKeyWidth)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: KeyboardMetrics.keyCornerRadius,
                                    style: .continuous
                                )
                                .fill(isSelected ? KeyPalette.active : KeyPalette.function)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    // MARK: - Actions

    /// Everything the view does exactly once per appearance, in named steps, so the
    /// appear-time contract is explicit rather than smuggled into a loader: read the
    /// shared preferences, report the initial height inputs, derive the opening shift.
    private func prepareForAppearance() {
        loadPreferences()
        onHeightInputsChanged?(.init(page: page, mode: layoutMode))
        applyAutocapitalization()
        if glideEnabled {
            // Warm the 50k-word parse off-main so the first glide never pays
            // it. The merge hops back to the main actor: candidates() runs on
            // main during a glide, and GlideLexicon is deliberately unlocked —
            // single-actor access IS the synchronization. (Resolves the Task 2
            // review's unsynchronized-state flag.)
            let supplementary = supplementaryWords
            Task.detached(priority: .utility) {
                _ = GlideLexicon.shared   // static-let init is thread-safe
                await MainActor.run {
                    GlideLexicon.shared.merge(words: supplementary)
                }
            }
        }
    }

    private func loadPreferences() {
        layoutMode = KeyboardPreferences.layoutMode
        keyFaceStyle = KeyboardPreferences.keyFaceStyle
        hapticsEnabled = KeyboardPreferences.hapticsEnabled
        emojiRecents = KeyboardPreferences.emojiRecents
        glideEnabled = KeyboardPreferences.glideTypingEnabled
        // Warm the engine only for users who can actually feel it: iOS drops
        // feedback-generator events from the extension without Full Access, so an
        // ungated prepare() spins the taptic engine for nothing.
        if hapticsEnabled && host.hasFullAccess() { Self.impact.prepare() }
    }

    private func insertLetter(_ letter: SleepTokenLetter) {
        insert(letter.englishInsert(shifted: autoShift.state.isUppercase))
        autoShift.didInsertLetter()
        applyAutocapitalization()
    }

    /// Every non-space keystroke interrupts the double-space window: the shortcut's
    /// rule is blind to interleaving by design, so consecutiveness is enforced here,
    /// where the keystrokes actually happen.
    private func insert(_ text: String) {
        haptic()
        onInsert(text)
        spaceTracker.interrupt()
        spaceTracker.noteLocalChange()
        glideUndo.interrupt()
    }

    /// Space is the one character key with a rule attached: a second space typed quickly
    /// after a word replaces the first with ". ".
    private func insertSpace() {
        // Correct before the space lands, the way stock does: the word is finished the
        // moment you reach for space, and replacing it afterwards would fight the
        // double-space shortcut for the same keystroke.
        autoCorrectFinishedWord()

        if PeriodShortcut.shouldSubstitute(
            contextBefore: host.contextBefore(),
            sinceLastSpace: spaceTracker.sinceLastSpace
        ) {
            haptic()
            onDeleteBackward()
            onInsert(". ")
            spaceTracker.interrupt()
            spaceTracker.noteLocalChange()
        } else {
            // insert() interrupts and re-opens are not its business; the record comes
            // after so the window belongs to this space.
            insert(" ")
            spaceTracker.recordSpace()
        }

        returnToLettersAfterSpace()
        applyAutocapitalization()
    }

    /// A finished glide: decode against the same geometry the page rendered with,
    /// insert stock-style, hand the alternates to the bar, arm whole-word undo.
    private func handleGlide(_ trace: [CGPoint], availableWidth: CGFloat) {
        let unit = KeyboardMetrics.keyUnit(availableWidth: availableWidth)
        let centers = KeyCenters.qwerty(availableWidth: availableWidth, keyHeight: keyHeight)
        let results = GlideDecoder.decode(trace: trace, centers: centers, keyUnit: unit,
                                          lexicon: .shared)
        let word = results.first?.word
            ?? GlideDecoder.nearestLetterSequence(trace: trace, centers: centers)
        guard !word.isEmpty else { return }

        let commit = GlideCommit.insertion(word: word, shift: autoShift.state,
                                           contextBefore: host.contextBefore(),
                                           lastInsertWasGlide: glideUndo.isArmed)
        insert(commit.text)                       // haptic, space window, echo note
        glideUndo.record(wordLength: commit.word.count)
        glideUndo.noteLocalChange()
        autoShift.didInsertLetter()
        applyAutocapitalization()

        suggestions = SuggestionSet(literal: commit.word,
                                    candidates: results.dropFirst().map(\.word))
        showsGlideAlternates = !results.isEmpty
    }

    /// Stock treats 123 and #+= as a detour: the space that ends a word brings the letters
    /// back on its own, and ours left the user stranded on symbols after every "?" or "!".
    /// Applied after the insert, so the character lands on the page it was typed from.
    private func returnToLettersAfterSpace() {
        let next = PageAfterSpace.page(
            from: page,
            typedSinceEntering: typedOnSymbolPage,
            numberPadField: host.usesNumberPad()
        )
        guard next != page else { return }
        setPage(next)
    }

    /// The one channel every deliberate page change goes through. It clears the space
    /// bar's arming, because a fresh visit to the symbol planes starts disarmed, and
    /// reports the height inputs the container reserves from. The 123 <-> #+= toggle is
    /// the deliberate exception: stock counts both planes as a single visit.
    private func setPage(_ next: KeyboardMetrics.Page) {
        page = next
        typedOnSymbolPage = false
        onHeightInputsChanged?(.init(page: page, mode: layoutMode))
    }

    /// `isRepeat` is false for the tap that begins a hold and true for every repeat after
    /// it, so a held delete does not fire twenty haptics a second.
    private func deleteBackward(isRepeat: Bool = false) {
        // One backspace right after a glide removes the whole word; the next
        // behaves normally. Repeats never consume it — a held delete is a
        // deliberate different gesture.
        if !isRepeat, let length = glideUndo.consume() {
            haptic()
            for _ in 0..<length { onDeleteBackward() }
            spaceTracker.interrupt()
            spaceTracker.noteLocalChange()
            applyAutocapitalization()
            return
        }
        if !isRepeat { haptic() }
        onDeleteBackward()
        spaceTracker.interrupt()
        spaceTracker.noteLocalChange()
        glideUndo.interrupt()
        applyAutocapitalization()
    }

    private func toggleShift() {
        haptic()
        // Stock engages caps lock on a quick second tap. Honour that first, then fall
        // through to the cycle, so both muscle memories reach the same state.
        if capsLockTap.isDoubleTap(at: ProcessInfo.processInfo.systemUptime) {
            autoShift.setCapsLock()
            return
        }
        // Deliberately no re-derivation after the tap: cancelling an auto-armed shift
        // must stick until the next keystroke, and re-deriving here would instantly
        // re-arm it at the very sentence start the user just cancelled.
        autoShift.userTappedShift()
    }

    /// Inserts an emoji as ordinary text and promotes it to the front of recents. Emoji
    /// are just characters, so nothing about the keyboard's plain-English contract
    /// changes — the payload was never the runes.
    private func insertEmoji(_ emoji: String) {
        haptic()
        insert(emoji)
        emojiRecents = EmojiCatalog.recents(after: emoji, in: emojiRecents)
        KeyboardPreferences.emojiRecents = emojiRecents
        applyAutocapitalization()
    }

    // MARK: - Correction

    /// Recomputes the bar from the word in progress. Called after every mutation, for
    /// the same reason `applyAutocapitalization` is: the proxy is the only truth, and it
    /// has just moved.
    private func refreshSuggestions() {
        guard host.correctionAllowed() else {
            if !suggestions.isEmpty { suggestions = SuggestionSet(literal: "", candidates: []) }
            return
        }
        let word = WordBoundary.currentWord(in: host.contextBefore() ?? "")
        let updated = suggestionEngine.suggestions(forPartialWord: word)
        if updated != suggestions { suggestions = updated }
    }

    /// Replaces the word in progress with `replacement`, by deleting exactly as many
    /// characters as the user typed. There is no range-replace on the proxy — delete and
    /// insert is the whole write surface.
    private func replaceCurrentWord(with replacement: String) {
        let word = WordBoundary.currentWord(in: host.contextBefore() ?? "")
        guard !word.isEmpty else { return }
        for _ in 0..<word.count { onDeleteBackward() }
        onInsert(replacement)
        spaceTracker.noteLocalChange()
    }

    /// The user tapped a correction.
    private func acceptSuggestion(_ replacement: String) {
        haptic()
        replaceCurrentWord(with: replacement)
        refreshSuggestions()
        applyAutocapitalization()
    }

    /// The user tapped their own spelling. Keep it, and stop offering to change it —
    /// otherwise the keyboard argues with them about their own vocabulary forever.
    private func keepTypedWord() {
        haptic()
        let word = WordBoundary.currentWord(in: host.contextBefore() ?? "")
        guard !word.isEmpty else { return }
        suggestionEngine.keepAsTyped(word)
        refreshSuggestions()
    }

    /// Applies a high-confidence correction as the word ends. Deliberately stricter than
    /// the bar: an ignored suggestion costs nothing, a wrong silent replacement is the
    /// worst thing this feature can do.
    private func autoCorrectFinishedWord() {
        guard !glideUndo.isArmed else { return }   // a glided word is already a dictionary word
        guard host.correctionAllowed() else { return }
        let word = WordBoundary.currentWord(in: host.contextBefore() ?? "")
        guard let replacement = suggestionEngine.autoReplacement(for: word) else { return }
        replaceCurrentWord(with: replacement)
    }

    /// Re-reads the field and arms or releases shift accordingly. Runs after anything
    /// that moves the cursor — every insert path, delete, and return — never after a
    /// manual shift tap. Manual states pass through untouched; auto-armed ones are
    /// recomputed, so calling this can only ever correct, not clobber.
    private func applyAutocapitalization() {
        autoShift.apply(type: host.autocapitalization(), contextBefore: host.contextBefore())
    }

    private func haptic() {
        // Declaring RequestsOpenAccess is not enough: iOS drops feedback generator events
        // from a keyboard extension until the user actually grants Full Access, so this
        // has to check rather than assume. Without it the call is a silent no-op.
        guard hapticsEnabled, host.hasFullAccess() else { return }
        Self.impact.impactOccurred(intensity: 0.7)
        // Re-arm for the next keystroke; a single warm-up only covers the first tap.
        Self.impact.prepare()
    }
}

// MARK: - Pages

private struct LetterPage: View {
    let layoutMode: LayoutMode
    let keyFaceStyle: KeyFaceStyle
    let shift: ShiftState
    let keyHeight: CGFloat
    let hintSize: CGFloat
    let faceSize: CGFloat
    /// Glide typing: QWERTY-only, off under VoiceOver, additive over the buttons.
    let glideEnabled: Bool
    let onLetter: (SleepTokenLetter) -> Void
    let onShift: () -> Void
    let onBackspace: (Bool) -> Void
    let onGlide: (_ trace: [CGPoint], _ availableWidth: CGFloat) -> Void

    @State private var glide = GlideSession()
    /// Keeps taps suppressed one runloop tick past lift, so the origin key's
    /// Button cannot fire on the same touch-up. During the drag itself the
    /// suppression rides `isGliding`.
    @State private var suppressesTaps = false
    /// True while the finger is down in THIS gesture. `@GestureState`, not
    /// `@State`, and the difference is the whole point (see BackspaceKey): its
    /// reset also runs when the system CANCELS the touch, so a call banner
    /// mid-glide cannot wedge the keyboard.
    @GestureState private var isGliding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rows: [[SleepTokenLetter]] {
        layoutMode == .qwerty ? KeyboardLayout.qwertyRows : KeyboardLayout.gridRows
    }

    var body: some View {
        // One GeometryReader for the page (not per key) so every row shares a key unit
        // and columns line up. Height is pinned by the caller, so it cannot expand.
        GeometryReader { geo in
            let unit = KeyboardMetrics.keyUnit(availableWidth: geo.size.width)
            VStack(spacing: KeyboardMetrics.rowGap) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: KeyboardMetrics.keyGap) {
                        if layoutMode == .qwerty && index == rows.count - 1 {
                            shiftKey
                        }

                        ForEach(row) { letter in
                            LetterKeyButton(
                                letter: letter,
                                keyFaceStyle: keyFaceStyle,
                                // Rune art carries no case, so those keys are pinned
                                // to false and never repaint on a shift change.
                                shifted: keyFaceStyle == .runeArt ? false : shift.isUppercase,
                                keyHeight: keyHeight,
                                hintSize: hintSize,
                                faceSize: faceSize,
                                fixedWidth: layoutMode == .qwerty ? unit : nil,
                                action: {
                                    guard !(isGliding || suppressesTaps) else { return }
                                    onLetter(letter)
                                }
                            )
                            .equatable()
                        }

                        if layoutMode == .qwerty && index == rows.count - 1 {
                            backspaceKey
                        }
                    }
                    // Centre the 9-key home row under the 10-key top row. The old flat
                    // 12pt literal could not be correct on more than one screen width.
                    .padding(
                        .horizontal,
                        layoutMode == .qwerty && index == rows.count - 2
                            ? KeyboardMetrics.homeRowInset(keyUnit: unit)
                            : 0
                    )
                }

                if layoutMode == .grid {
                    HStack(spacing: KeyboardMetrics.keyGap) {
                        shiftKey
                        Spacer(minLength: 0)
                        backspaceKey
                    }
                    .frame(height: keyHeight)
                }
            }
            .frame(width: geo.size.width, alignment: .top)
            .overlay {
                if glide.isActive {
                    GlideTrailView(points: glide.points, reduceMotion: reduceMotion)
                        .allowsHitTesting(false)
                }
            }
            .simultaneousGesture(glideGesture(width: geo.size.width), including: glideActive ? .all : .subviews)
            .onChange(of: isGliding) { _, active in
                // @GestureState's reset is the only signal a CANCELLED touch
                // gives us: falling while the session is still active means no
                // onEnded came — discard the glide, clear the trail. This is
                // the spec's cancellation clause, and GlideSession.cancel's
                // one production caller.
                guard !active, glide.isActive else { return }
                glide.cancel()
                suppressesTaps = false
            }
        }
    }

    private var glideActive: Bool {
        glideEnabled && layoutMode == .qwerty && !UIAccessibility.isVoiceOverRunning
    }

    private func glideGesture(width: CGFloat) -> some Gesture {
        let unit = KeyboardMetrics.keyUnit(availableWidth: width)
        return DragGesture(minimumDistance: unit / 2, coordinateSpace: .local)
            .updating($isGliding) { _, state, _ in state = true }
            .onChanged { value in
                guard glideActive else { return }
                if glide.points.first != value.startLocation {
                    // A glide must BEGIN on a letter: a thumb drifting off a
                    // held backspace or shift is not a word. 0.9 units reaches
                    // a letter key's corners and rejects the function keys.
                    guard nearestLetterDistance(to: value.startLocation, width: width)
                        <= unit * 0.9 else { return }
                }
                suppressesTaps = true
                glide.extend(start: value.startLocation, to: value.location)
            }
            .onEnded { value in
                guard glideActive, glide.isActive else { return }
                let trace = glide.finish(at: value.location)
                onGlide(trace, width)
                // Release tap suppression on the next runloop tick, after the
                // origin Button has had its chance to (not) fire for this touch.
                Task { @MainActor in suppressesTaps = false }
            }
    }

    private func nearestLetterDistance(to point: CGPoint, width: CGFloat) -> CGFloat {
        let centers = KeyCenters.qwerty(availableWidth: width, keyHeight: keyHeight)
        return centers.values.map { hypot($0.x - point.x, $0.y - point.y) }.min() ?? .infinity
    }

    private var shiftKey: some View {
        IconKeyButton(
            systemName: shift.symbolName,
            fill: shift == .off ? KeyPalette.function : KeyPalette.active,
            label: "Shift",
            value: shift.accessibilityValue,
            selected: shift != .off,
            action: onShift
        )
        .frame(width: KeyboardMetrics.functionKeyWidth, height: keyHeight)
    }

    private var backspaceKey: some View {
        BackspaceKey(keyHeight: keyHeight, onBackspace: onBackspace)
    }
}

/// The comet trail behind a gliding finger. Reduce Motion gets a uniform line —
/// same information, no animated fade.
private struct GlideTrailView: View {
    let points: [CGPoint]
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }
            if reduceMotion {
                var path = Path()
                path.addLines(points)
                context.stroke(path, with: .color(KeyPalette.active.opacity(0.55)),
                               style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            } else {
                // Newest segments brightest: opacity climbs along the trail.
                let count = points.count
                for index in 1..<count {
                    var segment = Path()
                    segment.move(to: points[index - 1])
                    segment.addLine(to: points[index])
                    let progress = Double(index) / Double(count)
                    context.stroke(segment, with: .color(KeyPalette.active.opacity(0.15 + 0.55 * progress)),
                                   style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

/// The candidate strip above the keys.
///
/// Stock marks a correction inside the text field itself, in blue, with alternatives
/// underneath. That is first-party: a keyboard extension can write text into a document
/// but never style it, so this bar is the same substitute every third-party keyboard
/// uses. The user's own spelling always occupies the first slot, quoted, so a correction
/// can be declined rather than merely undone.
private struct SuggestionBar: View {
    let suggestions: SuggestionSet
    let onKeepLiteral: () -> Void
    let onAccept: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            if suggestions.candidates.isEmpty {
                // Nothing to offer. The strip stays, because collapsing it would move
                // the keys under the thumb mid-word.
                Color.clear
            } else {
                slot(title: "\u{201C}\(suggestions.literal)\u{201D}", isLiteral: true) {
                    onKeepLiteral()
                }
                ForEach(suggestions.candidates, id: \.self) { candidate in
                    divider
                    slot(title: candidate, isLiteral: false) { onAccept(candidate) }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 1, height: 16)
    }

    private func slot(
        title: String,
        isLiteral: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isLiteral ? .regular : .semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isLiteral ? "Keep \(suggestions.literal)" : "Replace with \(title)"
        )
        .accessibilityHint(
            isLiteral ? "Keeps what you typed and stops correcting it" : ""
        )
    }
}

/// The 123 and #+= pages.
///
/// Stock flanks the short third row with the other symbol page's key on the left and
/// delete on the right. Ours used to run ten symbols across row three and put delete on
/// a row of its own, which is what made the keyboard grow 46pt whenever you tapped 123.
private struct SymbolsPage: View {
    let rows: [[String]]
    /// Title of the page this switches to — "#+=" from 123, "123" from #+=.
    let switchTitle: String
    let keyHeight: CGFloat
    let faceSize: CGFloat
    let onInsert: (String) -> Void
    let onSwitchPage: () -> Void
    let onBackspace: (Bool) -> Void

    var body: some View {
        VStack(spacing: KeyboardMetrics.rowGap) {
            ForEach(rows.indices, id: \.self) { index in
                let isLastRow = index == rows.count - 1
                HStack(spacing: KeyboardMetrics.keyGap) {
                    if isLastRow {
                        ChromeKeyButton(
                            content: .text(switchTitle),
                            fontSize: 14,
                            weight: .semibold,
                            label: switchTitle == "123"
                                ? "Switch to numbers"
                                : "Switch to more symbols",
                            action: onSwitchPage
                        )
                        .frame(width: KeyboardMetrics.functionKeyWidth, height: keyHeight)
                    }

                    ForEach(rows[index], id: \.self) { symbol in
                        SymbolKeyButton(symbol: symbol, faceSize: faceSize) {
                            onInsert(symbol)
                        }
                        .frame(height: keyHeight)
                    }

                    if isLastRow {
                        BackspaceKey(keyHeight: keyHeight, onBackspace: onBackspace)
                    }
                }
            }
        }
    }
}

/// The emoji page.
///
/// Apple's own emoji keyboard cannot be presented from a third-party extension — no
/// public API selects an input mode — so this is ours: a scrolling grid over our own
/// catalog, inserting plain text through the same path as every other key.
private struct EmojiPage: View {
    @Binding var category: EmojiCategory
    let recents: [String]
    let cellHeight: CGFloat
    let onInsert: (String) -> Void
    let onBackspace: (Bool) -> Void

    /// Height of the category strip. Sized to clear the 44pt touch target while leaving
    /// the grid the bulk of a page budget that is already fixed.
    private static let stripHeight: CGFloat = 44

    private var entries: [String] {
        category == .recents ? recents : EmojiCatalog.emoji(in: category)
    }

    var body: some View {
        VStack(spacing: KeyboardMetrics.rowGap) {
            if entries.isEmpty {
                // Recents on a fresh install. Teach the interface rather than showing
                // an empty box.
                VStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Emoji you use will appear here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(
                            .adaptive(minimum: 38),
                            spacing: KeyboardMetrics.keyGap
                        )],
                        spacing: KeyboardMetrics.rowGap
                    ) {
                        ForEach(entries, id: \.self) { emoji in
                            Button { onInsert(emoji) } label: {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: cellHeight)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(emoji)
                            .accessibilityAddTraits(.isKeyboardKey)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
            }

            HStack(spacing: KeyboardMetrics.keyGap) {
                ScrollView(.horizontal) {
                    HStack(spacing: 2) {
                        ForEach(EmojiCategory.allCases) { tab in
                            Button { category = tab } label: {
                                Image(systemName: tab.symbolName)
                                    .font(.footnote)
                                    .foregroundStyle(
                                        tab == category ? Color.primary : Color.secondary
                                    )
                                    .frame(width: 38, height: Self.stripHeight)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tab.accessibilityLabel)
                            .accessibilityAddTraits(
                                tab == category ? [.isButton, .isSelected] : .isButton
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)

                BackspaceKey(keyHeight: Self.stripHeight, onBackspace: onBackspace)
            }
            .frame(height: Self.stripHeight)
        }
    }
}

/// The globe key, in UIKit.
///
/// `handleInputModeList(from:with:)` is the only supported way to show the system
/// keyboard picker — and therefore the only route from here to Apple's Emoji keyboard —
/// but it needs the originating view *and* the `UIEvent`. SwiftUI hands us neither, so
/// this key is a `UIButton` that forwards both.
private struct GlobeKey: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(
            UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 16, weight: .medium
            )),
            for: .normal
        )
        button.tintColor = .label
        button.backgroundColor = KeyPalette.functionColor
        button.layer.cornerRadius = KeyboardMetrics.keyCornerRadius
        button.layer.cornerCurve = .continuous
        button.accessibilityLabel = "Next keyboard"
        button.accessibilityHint = "Double tap and hold to choose a keyboard"
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handlePress(_:event:)),
            for: .allTouchEvents
        )
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject {
        var onTap: () -> Void
        init(onTap: @escaping () -> Void) { self.onTap = onTap }

        /// The controller installs itself as the input view controller for this key so
        /// the long press can reach `handleInputModeList`. Walking the responder chain
        /// keeps the view free of a back-reference to the controller.
        @objc func handlePress(_ sender: UIButton, event: UIEvent) {
            guard let controller = sender.enclosingInputViewController else {
                // No controller in the chain (previews, tests): fall back to the plain
                // advance so the key is never inert.
                onTap()
                return
            }
            controller.handleInputModeList(from: sender, with: event)
        }
    }
}

private extension UIResponder {
    /// Nearest `UIInputViewController` up the responder chain.
    ///
    /// Deliberately not named `inputViewController`: `UIResponder` already declares that
    /// property with an entirely different meaning (the input view controller shown when
    /// *this* responder is first responder), and shadowing it here would be a trap for
    /// the next reader.
    var enclosingInputViewController: UIInputViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIInputViewController { return controller }
            responder = current.next
        }
        return nil
    }
}

// MARK: - Keycap chassis

/// The shared press feedback: highlight lands on touch-down, only the release fades
/// out, and Reduce Motion drops the scale. One definition serves the Button-based keys
/// (through KeyPressStyle) and the gesture-driven delete key alike — previously the
/// same four lines existed twice and had to be retuned in lockstep.
private struct PressAppearance: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isPressed ? 0.55 : 1)
            .scaleEffect(reduceMotion ? 1 : (isPressed ? 0.97 : 1))
            .animation(
                isPressed ? nil : (reduceMotion ? nil : .easeOut(duration: 0.08)),
                value: isPressed
            )
    }
}

private extension View {
    func pressAppearance(_ isPressed: Bool) -> some View {
        modifier(PressAppearance(isPressed: isPressed))
    }
}

/// The one delete key, shared by both pages so its icon, label, width, and repeat
/// behaviour cannot drift apart — the construction previously existed verbatim twice.
private struct BackspaceKey: View {
    let keyHeight: CGFloat
    let onBackspace: (Bool) -> Void

    var body: some View {
        RepeatingIconKeyButton(
            systemName: "delete.left",
            fill: KeyPalette.function,
            label: "Delete",
            action: onBackspace
        )
        .frame(width: KeyboardMetrics.functionKeyWidth, height: keyHeight)
    }
}

/// The one keycap shape. Four key structs previously re-declared it independently.
private struct KeycapBackground: ViewModifier {
    let fill: Color

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius, style: .continuous)
                .fill(fill)
        )
    }
}

private extension View {
    func keycap(fill: Color) -> some View {
        modifier(KeycapBackground(fill: fill))
    }
}

// MARK: - Keys

private struct LetterKeyButton: View, Equatable {
    let letter: SleepTokenLetter
    let keyFaceStyle: KeyFaceStyle
    /// Whether the Latin faces render uppercase. Keycaps flipping case with shift is
    /// how the user reads what case comes next — vital now that autocapitalization
    /// arms and releases shift silently. Normalised to `false` for the rune-art face
    /// by the caller, so pure-glyph keys never repaint on a shift change.
    let shifted: Bool
    let keyHeight: CGFloat
    let hintSize: CGFloat
    let faceSize: CGFloat
    let fixedWidth: CGFloat?
    let action: () -> Void

    /// Compares only the value inputs, ignoring the closure — which is freshly allocated
    /// per key per render. Keys repaint exactly when their rendered inputs change: a
    /// shift tap repaints the Latin faces (whose case flips) and leaves rune art alone.
    static func == (lhs: LetterKeyButton, rhs: LetterKeyButton) -> Bool {
        lhs.letter == rhs.letter
            && lhs.keyFaceStyle == rhs.keyFaceStyle
            && lhs.shifted == rhs.shifted
            && lhs.keyHeight == rhs.keyHeight
            && lhs.hintSize == rhs.hintSize
            && lhs.faceSize == rhs.faceSize
            && lhs.fixedWidth == rhs.fixedWidth
    }

    var body: some View {
        Button(action: action) {
            face
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .keycap(fill: KeyPalette.keycap)
        }
        .buttonStyle(KeyPressStyle())
        .frame(width: fixedWidth, height: keyHeight)
        // The Button is the sole accessibility element: SymbolGlyphView carries its own
        // label and hint for the host app's chart, which would otherwise make the two key
        // faces announce differently for the same letter.
        .accessibilityLabel(letter.upperLatin)
        .accessibilityAddTraits(.isKeyboardKey)
    }

    @ViewBuilder
    private var face: some View {
        switch keyFaceStyle {
        case .runeArt:
            SymbolGlyphView(letter: letter)
                .accessibilityHidden(true)
                .padding(.vertical, 6)
        case .runeHints:
            VStack(spacing: 1) {
                SymbolGlyphView(letter: letter)
                    .accessibilityHidden(true)
                Text(shifted ? letter.upperLatin : letter.latin)
                    .font(.system(size: hintSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 5)
        case .letters:
            Text(shifted ? letter.upperLatin : letter.latin)
                .font(.system(size: faceSize, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

private struct SymbolKeyButton: View {
    let symbol: String
    let faceSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: faceSize, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // A digit is a character key, not a function key: it takes the primary
                // keycap fill, leaving the dimmer fill to mean "modifier".
                .keycap(fill: KeyPalette.keycap)
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityAddTraits(.isKeyboardKey)
    }
}

/// Shift and backspace, which previously differed only in four literals.
private struct IconKeyButton: View {
    let systemName: String
    let fill: Color
    let label: String
    var value: String = ""
    var selected: Bool = false
    let action: () -> Void

    private var traits: AccessibilityTraits {
        selected ? [.isKeyboardKey, .isSelected] : [.isKeyboardKey]
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .keycap(fill: fill)
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAddTraits(traits)
    }
}

/// Delete, which repeats while held.
///
/// Built on a zero-distance drag rather than `Button` plus `onLongPressGesture`, because a
/// Button fires on release and this key has to fire on touch-down and keep firing until the
/// finger lifts. The drag also survives the finger sliding off the keycap, which is exactly
/// what happens when someone holds delete and their thumb relaxes.
private struct RepeatingIconKeyButton: View {
    let systemName: String
    let fill: Color
    let label: String
    /// `false` for the tap that starts the hold, `true` for every repeat after it, so the
    /// caller can fire feedback once rather than twenty times a second.
    let action: (Bool) -> Void

    /// `@GestureState`, not `@State`, and the difference is the whole point: its reset
    /// closure runs when the system CANCELS the touch (incoming call banner,
    /// Notification Center pulled over the keyboard) as well as when it ends. With
    /// `@State`, `onEnded` never arrived in those cases, the view stayed visible so
    /// `onDisappear` never fired either, and delete ran away at repeat rate while the
    /// user looked at the banner.
    @GestureState private var isPressed = false
    @State private var repeater: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .keycap(fill: fill)
            .pressAppearance(isPressed)
            // The glyph does not fill the keycap, so without this the corners of the key
            // are visually part of it but not touchable.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
            )
            // All lifecycle flows from the one pressed flag: touch-down fires the first
            // delete and starts the repeater; end, cancellation, and (below) removal
            // all stop it. No path exists where the repeater outlives the touch.
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    action(false)
                    startRepeating()
                } else {
                    stopRepeating()
                }
            }
            .onDisappear(perform: stopRepeating)
            .accessibilityLabel(label)
            // A gesture-only view exposes no activate action of its own, and VoiceOver,
            // Switch Control, and Full Keyboard Access all depend on one. This restores
            // what the Button-based key provided: one deletion per activation.
            .accessibilityAction { action(false) }
            .accessibilityAddTraits([.isKeyboardKey, .isButton])
    }

    private func startRepeating() {
        repeater?.cancel()
        repeater = Task { @MainActor in
            // The gap that separates a tap from a hold. Cancelling during it leaves the
            // single delete already emitted on touch-down and nothing more.
            try? await Task.sleep(for: .seconds(KeyRepeat.initialDelay))

            var fired = 1
            while !Task.isCancelled {
                action(true)
                try? await Task.sleep(for: .seconds(KeyRepeat.interval(forRepeat: fired)))
                fired += 1
            }
        }
    }

    private func stopRepeating() {
        repeater?.cancel()
        repeater = nil
    }
}

/// Bottom-bar keys. Space and return EMIT characters, so they opt into `.isKeyboardKey`
/// and VoiceOver's lift-to-type; the mode-switching keys (globe, layout, style, 123)
/// deliberately do not — VoiceOver keeps its confirm-before-acting behaviour for actions
/// that change the keyboard rather than the text. The July trait rollout opted the whole
/// bar out; that over-included exactly the two most-typed keys.
private struct ChromeKeyButton: View {
    enum Content {
        case text(String)
        case symbol(String)
    }

    let content: Content
    var fontSize: CGFloat = 14
    var weight: Font.Weight = .regular
    let label: String
    var fill: Color = KeyPalette.function
    /// True for keys that insert text (space, return): adds `.isKeyboardKey`.
    var isTypingKey: Bool = false
    /// Return honours `enablesReturnKeyAutomatically`; everything else is always on.
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch content {
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.body.weight(weight))
                case .text(let title):
                    Text(title)
                        .font(.system(size: fontSize, weight: weight, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        // Breathing room before the cap edge: without it a long
                        // adaptive return title ("Continue") renders edge-to-edge.
                        .padding(.horizontal, 4)
                }
            }
            .opacity(enabled ? 1 : 0.35)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .keycap(fill: fill)
        }
        .buttonStyle(KeyPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isTypingKey ? .isKeyboardKey : [])
    }
}

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.pressAppearance(configuration.isPressed)
    }
}
