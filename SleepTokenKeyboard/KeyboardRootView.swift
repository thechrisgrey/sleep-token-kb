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
    /// Live reads of the field being edited: what precedes the cursor, how it wants text
    /// capitalised, what its return key means, and whether Full Access was granted.
    let host: HostField
    /// Reports the layout mode whenever it changes, so the container re-reserves height
    /// from the same input the content lays itself out with -- one value, one channel.
    /// The page deliberately does not travel: the container reserves the tallest page
    /// for the layout, so a page change never changes the height.
    var onLayoutModeChanged: ((LayoutMode) -> Void)? = nil

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

    /// Whether the space bar's return to letters is armed for this visit to the symbol
    /// planes. Stock arms it on the first keystroke of a visit, not on arrival — `123
    /// space` stays on 123 so a "meet me at " keeps the digits one tap away, while `123
    /// 5 space` goes back. Every deliberate page change starts a fresh visit through
    /// `setPage`; the 123 <-> #+= toggle deliberately does not, because stock counts the
    /// two symbol planes as one visit. The sequences are pinned in SymbolVisitTests.
    @State private var symbolVisit = SymbolVisit()

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
    /// quick second tap is the only road into caps lock (plus the named accessibility
    /// action), and a tap on the locked state is the road out; the old three-tap cycle
    /// is gone. See `AutoShift.userTappedShift` and `CapsLockTap`.
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
    /// Token holder for in-flight `SpellWorker` requests. Reference type in `@State`
    /// for the same reason `spaceTracker` is: nothing renders it.
    @State private var suggestionRequest = SuggestionRequest()
    /// The road back from the last silent replacement: offered in the bar while the
    /// caret sits on the corrected word. A value type; `@State` keeps it per view.
    @State private var correctionUndo = CorrectionUndo()

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Scaled within the keyboard's fixed height budget. The ceiling is
    /// `KeyboardMetrics.maximumContentSizeCategory`, applied by the controller to the
    /// hosting view's trait collection — which is what these wrappers read. A
    /// `.dynamicTypeSize` modifier inside `body` only ever reached the descendants, so
    /// the faces kept growing past the clamp while the keys they sat in did not.
    @ScaledMetric(relativeTo: .caption2) private var hintSize: CGFloat = 9
    @ScaledMetric(relativeTo: .body) private var letterFaceSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var symbolFaceSize: CGFloat = 16
    /// The candidate bar scales with the keycaps it sits above: these are the exact
    /// words a low-vision user has to read to accept or decline a correction, and a
    /// fixed size left them small while every key face grew.
    @ScaledMetric(relativeTo: .body) private var candidateSize: CGFloat = 16
    /// The chrome captions scale with the faces they sit beside; a fixed 14pt "space"
    /// under 31pt letters inverted the hierarchy at accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var chromeFaceSize: CGFloat = KeyboardMetrics.chromeFaceSize
    @ScaledMetric(relativeTo: .body) private var returnFaceSize: CGFloat = KeyboardMetrics.returnFaceSize

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
        VStack(spacing: KeyboardMetrics.rowGap(compact: isCompact)) {
            SuggestionBar(
                suggestions: suggestions,
                faceSize: candidateSize,
                onKeepLiteral: keepTypedWord,
                onAccept: acceptSuggestion
            )
            .frame(height: KeyboardMetrics.suggestionBarHeight(compact: isCompact))
            // The container reserves the tallest page for the layout, and this VStack
            // is bottom-anchored inside that reservation. The slack above a shorter
            // page used to sit ABOVE the bar, dropping it under the thumb by 12pt on
            // every face change and by a row on every tap of 123. Giving the bar's
            // frame the slack pins the bar to the top and the keys to the bottom.
            .frame(maxHeight: .infinity, alignment: .top)

            switch page {
            case .symbols, .symbolsAlt:
                SymbolsPage(
                    rows: page == .symbols
                        ? KeyboardLayout.symbolRows
                        : KeyboardLayout.symbolAltRows,
                    switchTitle: page == .symbols ? "#+=" : "123",
                    keyHeight: keyHeight,
                    faceSize: symbolFaceSize,
                    chromeFaceSize: chromeFaceSize,
                    // Digits and punctuation move the cursor like any other insert, so
                    // they re-derive too — this was the one mutation path that skipped
                    // it and left shift stale on the 123 page.
                    onInsert: { symbol in
                        // Word-ending punctuation applies the pending correction
                        // first, so "teh." ships as "the." — space and return
                        // already did; this was the word ending that skipped it.
                        if symbol.count == 1, let character = symbol.first,
                           WordBoundary.isBoundary(character) {
                            autoCorrectFinishedWord()
                        }
                        insert(symbol)
                        // The keystroke that arms the space bar's return to letters.
                        symbolVisit.didType()
                        applyAutocapitalization()
                    },
                    onSwitchPage: {
                        haptic()
                        // Not `setPage`: stock counts 123 and #+= as one visit, so a digit
                        // typed on 123 still arms the space bar over on #+=.
                        page = (page == .symbols) ? .symbolsAlt : .symbols
                        symbolVisit.didTogglePlane()
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
                    onCapsLock: engageCapsLock,
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
        // The same ceiling the controller applies to the hosting view, restated here so
        // a preview or test host without the controller clamps identically.
        .dynamicTypeSize(...(DynamicTypeSize(KeyboardMetrics.maximumContentSizeCategory) ?? .accessibility2))
        .onAppear(perform: prepareForAppearance)
        .onChange(of: fieldGeneration) {
            // A different field: the old field's shift provenance, double-space window,
            // correction memo and page are meaningless here. Start clean and derive for
            // the new field — on letters, the way stock presents a fresh responder.
            autoShift = AutoShift()
            spaceTracker.interrupt()
            glideUndo.interrupt()
            capsLockTap.interrupt()
            correctionUndo.interrupt()
            symbolVisit = SymbolVisit()
            if page != .letters { setPage(.letters) }
            emojiCategory = EmojiCategory.landing(recentsEmpty: emojiRecents.isEmpty)
            applyAutocapitalization()
            refreshSuggestions()
        }
        .onChange(of: hostTextGeneration) {
            // A change this keyboard did not cause -- a cursor jump, a host-side clear,
            // a same-trait field switch -- breaks double-space consecutiveness; the echo
            // of our own keystroke passes through the tracker silently.
            let external = spaceTracker.hostTextDidChange()
            glideUndo.hostTextDidChange()
            if external {
                // An external change is not the second tap of a shift double tap, and
                // the caret may no longer sit on the word the memo was recorded for.
                // The echo of a local keystroke is NOT an interrupt: `insert()` already
                // interrupted synchronously, and a slow host's echo of the letter
                // before a quick shift-shift used to land between the two taps.
                capsLockTap.interrupt()
                correctionUndo.interrupt()
            }
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
                fontSize: chromeFaceSize,
                weight: .semibold,
                label: page == .letters ? "Switch to numbers" : "Switch to letters"
            ) {
                haptic()
                setPage(page == .letters ? .symbols : .letters)
            }
            .frame(width: KeyboardMetrics.minimumTouchTarget)

            if needsInputModeSwitchKey {
                // UIKit, not a SwiftUI Button: `handleInputModeList(from:with:)` needs
                // both the originating view and the UIEvent, and only a UIControl action
                // hands us those. Tap still advances; long press opens the picker, which
                // is the stock gesture and the only supported route to Apple's Emoji
                // keyboard for a third-party extension.
                GlobeKey(onTap: onNextKeyboard, onPress: haptic)
                    .frame(width: KeyboardMetrics.globeKeyWidth)
            }

            // One label whatever the page: on the emoji page this key is the selected
            // "Emoji" key, not a second "Switch to letters" beside the ABC key — two
            // adjacent keys announcing the same label and action were indistinguishable
            // to VoiceOver. Selected-and-activating-deselects is the shift key's pattern.
            ChromeKeyButton(
                content: .symbol(page == .emoji ? "keyboard" : "face.smiling"),
                weight: .medium,
                label: "Emoji",
                fill: page == .emoji ? KeyPalette.active : KeyPalette.function,
                selected: page == .emoji
            ) {
                haptic()
                setPage(page == .emoji ? .letters : .emoji)
            }
            .frame(width: KeyboardMetrics.emojiKeyWidth)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                    haptic()
                    showsKeyboardOptions = true
                }
            )
            .accessibilityHint("Double tap and hold for layout and key face")
            // The assistive route into the panel: a 0.4s hold is not a gesture VoiceOver
            // or Switch Control users can be asked to perform.
            .accessibilityAction(named: Text("Keyboard options")) {
                showsKeyboardOptions = true
            }

            // The space bar is a primary key, so it takes the primary keycap fill.
            ChromeKeyButton(
                content: .text("space"),
                fontSize: chromeFaceSize,
                weight: .regular,
                label: "Space",
                fill: KeyPalette.keycap,
                isTypingKey: true
            ) {
                insertSpace()
            }
            .frame(maxWidth: .infinity)

            // The cap names the host field's action -- search, send, done -- rather
            // than always reading "return", takes stock's tinted action fill for those
            // actions, and honours enablesReturnKeyAutomatically the way the system
            // keyboard does: disabled until the field has text. The controller rebuilds
            // this view on every host text change, so all three stay current. One read
            // serves the cap, the fill and the spoken label alike.
            let returnKey = host.returnKeyType()
            let isAction = ReturnKeyTitle.isAction(for: returnKey)
            ChromeKeyButton(
                content: .text(ReturnKeyTitle.title(for: returnKey)),
                fontSize: returnFaceSize,
                weight: .semibold,
                minimumScaleFactor: KeyboardMetrics.returnMinimumScaleFactor,
                label: ReturnKeyTitle.accessibilityLabel(for: returnKey),
                fill: isAction ? KeyPalette.action : KeyPalette.function,
                titleColor: isAction ? KeyPalette.actionTitle : Color.primary,
                isTypingKey: true,
                enabled: host.returnKeyEnabled()
            ) {
                // Return finishes a word as surely as space does, and stock applies
                // the pending correction at both. Before the newline lands, so the
                // replacement targets the word being ended.
                autoCorrectFinishedWord()
                insert("\n")
                applyAutocapitalization()
            }
            .frame(width: KeyboardMetrics.returnKeyWidth)
        }
    }

    /// Layout and key face, reachable by long-pressing the emoji key or through the
    /// key's named "Keyboard options" action. Both are still in the host app's settings;
    /// this is the in-keyboard shortcut they used to have as two permanent chrome keys.
    private var keyboardOptionsPanel: some View {
        KeyboardOptionsPanel(
            layoutMode: layoutMode,
            keyFaceStyle: keyFaceStyle,
            onSelectLayout: { mode in
                layoutMode = mode
                KeyboardPreferences.layoutMode = mode
                onLayoutModeChanged?(mode)
            },
            // The key face changes row height, not reserved height: the container
            // reserves the tallest face, so nothing is reported.
            onSelectKeyFace: { style in
                keyFaceStyle = style
                KeyboardPreferences.keyFaceStyle = style
            },
            onDismiss: { showsKeyboardOptions = false },
            haptic: haptic
        )
    }

    // MARK: - Actions

    /// Everything the view does exactly once per appearance, in named steps, so the
    /// appear-time contract is explicit rather than smuggled into a loader: read the
    /// shared preferences, report the initial height inputs, derive the opening shift.
    private func prepareForAppearance() {
        loadPreferences()
        onLayoutModeChanged?(layoutMode)
        applyAutocapitalization()
        if glideEnabled {
            // Warm the 50k-word parse off-main so the first glide never pays
            // it. The supplementary merge deliberately does NOT live here: the
            // view reads its inputs in onAppear, which the async lexicon
            // delivery normally loses to. It lives in the controller's
            // completion, where the words actually arrive.
            Task.detached(priority: .utility) { _ = GlideLexicon.shared }
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
        // Typing on past a corrected word makes it the user's own again.
        correctionUndo.interrupt()
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
        // A keystroke between two shift taps means they were never a double tap:
        // shift-letter-shift at speed is two one-shots, not a caps lock.
        capsLockTap.interrupt()
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
            // The first space comes out, ". " goes in through the one insert path, so
            // the bookkeeping (haptic, window, echo, caps-lock tap) cannot drift from
            // every other keystroke's. The space is a VoiceOver-silent key; say what
            // landed, as the autocorrection announcement does.
            onDeleteBackward()
            insert(". ")
            AccessibilityNotification.Announcement(PeriodShortcut.announcement).post()
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
        let centers = KeyCenters.qwerty(availableWidth: availableWidth, keyHeight: keyHeight, compact: isCompact)
        let results = GlideDecoder.decode(trace: trace, centers: centers, keyUnit: unit,
                                          lexicon: .shared)
        let word = results.first?.word
            ?? GlideDecoder.nearestLetterSequence(trace: trace, centers: centers)
        guard !word.isEmpty else { return }

        let shift = autoShift.state
        let commit = GlideCommit.insertion(word: word, shift: shift,
                                           contextBefore: host.contextBefore(),
                                           lastInsertWasGlide: glideUndo.isArmed)
        insert(commit.text)                       // haptic, space window, echo note
        correctionUndo.interrupt()
        glideUndo.record(wordLength: commit.word.count)
        glideUndo.noteLocalChange()
        autoShift.didInsertLetter()
        applyAutocapitalization()

        // A glide's alternates, not spell candidates: four fixed columns, and the bar
        // must not treat the committed word as something to correct.
        suggestionRequest.cancelAll()
        suggestions = SuggestionSet(
            literal: commit.word,
            candidates: results.dropFirst().map { GlideCommit.cased($0.word, shift: shift) },
            origin: .glide
        )
        showsGlideAlternates = !results.isEmpty
    }

    /// Stock treats 123 and #+= as a detour: the space that ends a word brings the letters
    /// back on its own, and ours left the user stranded on symbols after every "?" or "!".
    /// Applied after the insert, so the character lands on the page it was typed from.
    private func returnToLettersAfterSpace() {
        let next = PageAfterSpace.page(
            from: page,
            typedSinceEntering: symbolVisit.isArmed,
            numberPadField: host.usesNumberPad()
        )
        guard next != page else { return }
        setPage(next)
    }

    /// The one channel every deliberate page change goes through. It starts a fresh,
    /// disarmed symbol visit, and lands the emoji page on the tab stock would — Recents
    /// once there are any, Smileys before, so a new user sees emoji rather than the
    /// clock tab's teaching text. The 123 <-> #+= toggle is the deliberate exception:
    /// stock counts both planes as a single visit. Height is not reported: the
    /// container reserves the tallest page, so a page change never changes it.
    private func setPage(_ next: KeyboardMetrics.Page) {
        page = next
        symbolVisit.didChangePage()
        if next == .emoji {
            emojiCategory = EmojiCategory.landing(recentsEmpty: emojiRecents.isEmpty)
        }
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
            capsLockTap.interrupt()
            applyAutocapitalization()
            return
        }
        if !isRepeat { haptic() }
        onDeleteBackward()
        spaceTracker.interrupt()
        spaceTracker.noteLocalChange()
        glideUndo.interrupt()
        capsLockTap.interrupt()
        applyAutocapitalization()
    }

    private func toggleShift() {
        haptic()
        // Stock engages caps lock on a quick second tap. Honour that first; any
        // slower tap toggles — an engaged state releases, off arms one shot.
        if capsLockTap.isDoubleTap(at: ProcessInfo.processInfo.systemUptime) {
            autoShift.setCapsLock()
            return
        }
        // Deliberately no re-derivation after the tap: cancelling an auto-armed shift
        // must stick until the next keystroke, and re-deriving here would instantly
        // re-arm it at the very sentence start the user just cancelled.
        autoShift.userTappedShift()
    }

    /// The assistive route into caps lock: VoiceOver and Switch Control surface this as
    /// a named action on the shift key, because two activations inside 0.35 seconds is
    /// not a gesture those users can be asked to perform.
    private func engageCapsLock() {
        haptic()
        autoShift.setCapsLock()
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
        guard host.correctionAllowed(),
              // A caret inside a word sees only the fragment left of itself, and
              // accepting a candidate would splice into the word's middle. Stock
              // goes quiet mid-word; so does the bar.
              !WordBoundary.caretIsInsideWord(contextAfter: host.contextAfter())
        else {
            suggestionRequest.cancelAll()
            if !suggestions.isEmpty { suggestions = SuggestionSet(literal: "", candidates: []) }
            return
        }
        let word = WordBoundary.currentWord(in: host.contextBefore() ?? "")

        // The caret is back on a word this keyboard silently replaced: offer what was
        // typed, the way stock does, before the engine can call the replacement a
        // known word and show nothing.
        if let typed = correctionUndo.original(ifCurrentWordIs: word) {
            suggestionRequest.cancelAll()
            let offer = SuggestionSet(literal: word, candidates: [typed])
            if offer != suggestions { suggestions = offer }
            return
        }

        // Anything the engine can answer for free — a kept word, one under the length
        // floor, the pronoun, or a memo already filled — lands in this keystroke.
        if let immediate = suggestionEngine.immediateSuggestions(forPartialWord: word) {
            suggestionRequest.cancelAll()
            if immediate != suggestions { suggestions = immediate }
            return
        }

        // Otherwise the dictionary has to be consulted, which costs milliseconds this
        // keystroke does not have. Show the literal now and let the candidates land a
        // beat later, the way stock's bar fills in.
        let token = suggestionRequest.issue()
        let literalOnly = SuggestionSet(literal: word, candidates: [])
        if literalOnly != suggestions { suggestions = literalOnly }

        // Tracked so the next keystroke cancels it: a superseded request used to run
        // `guesses()` to completion in the actor and merely lose the right to publish.
        suggestionRequest.track(Task { @MainActor in
            let candidates = await SpellWorker.shared.corrections(for: word)
            // A newer keystroke has already asked a different question.
            guard suggestionRequest.isCurrent(token) else { return }
            suggestionEngine.remember(word, corrections: candidates)
            let updated = SuggestionSet(literal: word, candidates: candidates)
            if updated != suggestions { suggestions = updated }
        })
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

    /// The user tapped a correction — or, after a silent replacement, the word they
    /// originally typed. Taking a correction back is a rejection of it: stock stops
    /// correcting that word, and so does this.
    private func acceptSuggestion(_ replacement: String) {
        haptic()
        let word = WordBoundary.currentWord(in: host.contextBefore() ?? "")
        let isRevert = correctionUndo.original(ifCurrentWordIs: word) == replacement
        replaceCurrentWord(with: replacement)
        if isRevert { suggestionEngine.keepAsTyped(replacement) }
        correctionUndo.interrupt()
        refreshSuggestions()
        applyAutocapitalization()
    }

    /// The user tapped their own spelling. Keep it, and stop offering to change it —
    /// otherwise the keyboard argues with them about their own vocabulary forever.
    /// The engine's kept set gates every path before either checker is consulted, so
    /// there is nothing to tell the bar's worker.
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
        // Never splice into a word the caret merely sits inside: the fragment left
        // of the caret is not a finished word, whatever the checker makes of it.
        guard !WordBoundary.caretIsInsideWord(contextAfter: host.contextAfter()) else { return }
        let word = WordBoundary.currentWord(in: host.contextBefore() ?? "")
        guard let replacement = suggestionEngine.autoReplacement(for: word) else { return }
        replaceCurrentWord(with: replacement)
        correctionUndo.record(typed: word, replacement: replacement)
        // High priority: the caller inserts the boundary in the same call, and
        // VoiceOver's typing echo of that space or return used to cut the default-
        // priority announcement to a syllable.
        var spoken = AttributedString(SuggestionEngine.announcement(replacing: word, with: replacement))
        spoken.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(spoken).post()
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

/// The candidate strip above the keys.
///
/// Stock marks a correction inside the text field itself, in blue, with alternatives
/// underneath. That is first-party: a keyboard extension can write text into a document
/// but never style it, so this bar is the same substitute every third-party keyboard
/// uses. The user's own spelling always occupies the first slot, quoted, so a correction
/// can be declined rather than merely undone.
/// The candidate strip above the keys.
///
/// Its geometry is fixed by `origin.slotCount`, never by how many candidates happen to
/// exist: the columns and the gaps between them hold still while `UITextChecker` results
/// come and go, so a slot the thumb was aiming at does not move out from under it
/// mid-word. Unfilled columns render blank, and their dividers render clear rather than
/// collapsing, which is what keeps the occupied columns the same width throughout.
private struct SuggestionBar: View {
    let suggestions: SuggestionSet
    let faceSize: CGFloat
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
                // One pass per reserved column, occupied or not.
                ForEach(0..<(suggestions.origin.slotCount - 1), id: \.self) { index in
                    let candidate = index < suggestions.candidates.count
                        ? suggestions.candidates[index]
                        : nil
                    divider(visible: candidate != nil)
                    if let candidate {
                        slot(title: candidate, isLiteral: false) { onAccept(candidate) }
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Always occupies its 1pt, so the columns either side keep their width whether or
    /// not the candidate beyond it exists.
    private func divider(visible: Bool) -> some View {
        Rectangle()
            .fill(visible ? Color.primary.opacity(0.18) : Color.clear)
            .frame(width: 1, height: 16)
    }

    private func slot(
        title: String,
        isLiteral: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: faceSize, weight: isLiteral ? .regular : .semibold))
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

/// The globe key, in UIKit.
///
/// `handleInputModeList(from:with:)` is the only supported way to show the system
/// keyboard picker — and therefore the only route from here to Apple's Emoji keyboard —
/// but it needs the originating view *and* the `UIEvent`. SwiftUI hands us neither, so
/// this key is a `UIButton` that forwards both.
private struct GlobeKey: UIViewRepresentable {
    let onTap: () -> Void
    /// Touch-down feedback, the same haptic every other bar key fires.
    let onPress: () -> Void

    func makeUIView(context: Context) -> UIButton {
        // Configuration-based so the press appearance can be driven from the button's
        // own state: the system button only dimmed its glyph on touch-down while every
        // other key drops the whole cap to 55% and, outside Reduce Motion, to 97%.
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = .zero
        // Text-style, not a point size: scales with Dynamic Type exactly as the SF
        // Symbols on the SwiftUI keys do, and the hosting view's content-size ceiling
        // is inherited through the trait collection.
        configuration.image = UIImage(
            systemName: "globe",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)
                .applying(UIImage.SymbolConfiguration(weight: .medium))
        )
        configuration.baseForegroundColor = .label
        let button = UIButton(configuration: configuration)
        // The cap is the button's own layer, not the configuration's background: that
        // is the one place a continuous corner curve — the keycap shape every SwiftUI
        // key draws — can be set.
        button.backgroundColor = KeyPalette.functionColor
        button.layer.cornerRadius = KeyboardMetrics.keyCornerRadius
        button.layer.cornerCurve = .continuous
        button.configurationUpdateHandler = { button in
            let pressed = button.isHighlighted
            let scale: CGFloat = pressed && !UIAccessibility.isReduceMotionEnabled ? 0.97 : 1
            let apply = {
                button.alpha = pressed ? 0.55 : 1
                button.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
            // Highlight lands immediately; only the release fades out — PressAppearance.
            if pressed || UIAccessibility.isReduceMotionEnabled {
                apply()
            } else {
                UIView.animate(withDuration: 0.08, delay: 0, options: .curveEaseOut, animations: apply)
            }
        }
        button.accessibilityLabel = "Next keyboard"
        button.accessibilityHint = "Double tap and hold to choose a keyboard"
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleTouchDown),
            for: .touchDown
        )
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handlePress(_:event:)),
            for: .allTouchEvents
        )
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onPress = onPress
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap, onPress: onPress) }

    final class Coordinator: NSObject {
        var onTap: () -> Void
        var onPress: () -> Void
        init(onTap: @escaping () -> Void, onPress: @escaping () -> Void) {
            self.onTap = onTap
            self.onPress = onPress
        }

        @objc func handleTouchDown() { onPress() }

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
/// same four lines existed twice and had to be retuned in lockstep. Internal, like the
/// rest of the chassis, so LetterPage, the options panel and the symbol and emoji pages
/// draw with it from their own files.
struct PressAppearance: ViewModifier {
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

extension View {
    func pressAppearance(_ isPressed: Bool) -> some View {
        modifier(PressAppearance(isPressed: isPressed))
    }
}

/// The one delete key, shared by every page so its icon, label, width, and repeat
/// behaviour cannot drift apart — the construction previously existed verbatim twice.
/// Internal, not private: EmojiPage builds its strip around this key from its own file.
struct BackspaceKey: View {
    /// Passed rather than derived: on the letter and symbol pages delete is a grid key
    /// and takes the grid's function width, while the emoji strip is chrome with no key
    /// unit to speak of and takes the plain touch-target floor.
    var width: CGFloat = KeyboardMetrics.minimumTouchTarget
    let keyHeight: CGFloat
    let onBackspace: (Bool) -> Void

    var body: some View {
        RepeatingIconKeyButton(
            systemName: "delete.left",
            fill: KeyPalette.function,
            label: "Delete",
            action: onBackspace
        )
        .frame(width: width, height: keyHeight)
    }
}

/// The one keycap shape. Four key structs previously re-declared it independently.
struct KeycapBackground: ViewModifier {
    let fill: Color

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius, style: .continuous)
                .fill(fill)
        )
    }
}

extension View {
    func keycap(fill: Color) -> some View {
        modifier(KeycapBackground(fill: fill))
    }
}

// MARK: - Keys

struct LetterKeyButton: View, Equatable {
    let letter: SleepTokenLetter
    let keyFaceStyle: KeyFaceStyle
    /// Whether the Latin faces render uppercase. Keycaps flipping case with shift is
    /// how the user reads what case comes next — vital now that autocapitalization
    /// arms and releases shift silently. Normalised to `false` for the rune-art face
    /// by the caller, whose glyphs carry no case.
    let shifted: Bool
    /// Whether VoiceOver speaks "capital". Separate from `shifted` and never
    /// normalised: the spoken label tells the truth on every face.
    let spokenUppercase: Bool
    let keyHeight: CGFloat
    let hintSize: CGFloat
    let faceSize: CGFloat
    let fixedWidth: CGFloat?
    let action: () -> Void

    /// Compares only the value inputs, ignoring the closure — which is freshly allocated
    /// per key per render. Keys repaint exactly when their rendered inputs change: a
    /// shift tap now touches every face, since the spoken case flips even where the
    /// drawn face does not.
    static func == (lhs: LetterKeyButton, rhs: LetterKeyButton) -> Bool {
        lhs.letter == rhs.letter
            && lhs.keyFaceStyle == rhs.keyFaceStyle
            && lhs.shifted == rhs.shifted
            && lhs.spokenUppercase == rhs.spokenUppercase
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
        .accessibilityLabel(letter.spokenKeyName(uppercase: spokenUppercase))
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
                    // Its own role: `.secondary` over the keycap resolved to ~3.4:1 on
                    // the one face whose job is the Latin mapping.
                    .foregroundStyle(KeyPalette.hint)
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

/// Internal, not private: SymbolsPage builds its rows from this key in its own file.
struct SymbolKeyButton: View {
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
struct IconKeyButton: View {
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
struct RepeatingIconKeyButton: View {
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
/// Internal, not private: SymbolsPage builds its page-switch key from this in its own file.
struct ChromeKeyButton: View {
    enum Content {
        case text(String)
        case symbol(String)
    }

    let content: Content
    /// Already scaled by the caller's `@ScaledMetric`; the default is the unscaled
    /// chrome face for callers without one.
    var fontSize: CGFloat = KeyboardMetrics.chromeFaceSize
    var weight: Font.Weight = .regular
    var minimumScaleFactor: CGFloat = KeyboardMetrics.chromeMinimumScaleFactor
    let label: String
    var fill: Color = KeyPalette.function
    var titleColor: Color = .primary
    /// True for keys that insert text (space, return): adds `.isKeyboardKey`.
    var isTypingKey: Bool = false
    /// True for a mode key whose mode is showing (the emoji key on the emoji page):
    /// adds `.isSelected`, the shift key's pattern.
    var selected: Bool = false
    /// Return honours `enablesReturnKeyAutomatically`; everything else is always on.
    var enabled: Bool = true
    let action: () -> Void

    private var traits: AccessibilityTraits {
        var traits: AccessibilityTraits = []
        if isTypingKey { traits.insert(.isKeyboardKey) }
        if selected { traits.insert(.isSelected) }
        return traits
    }

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
                        .minimumScaleFactor(minimumScaleFactor)
                        // Breathing room before the cap edge: without it a long
                        // adaptive return title ("continue") renders edge-to-edge.
                        .padding(.horizontal, KeyboardMetrics.chromeTitleInset)
                }
            }
            .foregroundStyle(titleColor)
            .opacity(enabled ? 1 : 0.35)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .keycap(fill: fill)
        }
        .buttonStyle(KeyPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(traits)
    }
}

struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.pressAppearance(configuration.isPressed)
    }
}
