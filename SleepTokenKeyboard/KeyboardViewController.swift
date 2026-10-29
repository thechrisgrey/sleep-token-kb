import UIKit
import SwiftUI

/// Custom keyboard: ritual or ABC keycaps; always inserts English letters.
///
/// The controller owns every host interaction (text insertion, keyboard switching) and
/// reserves height by running the same `KeyboardMetrics` arithmetic the SwiftUI content
/// lays itself out with, so the container cannot promise less space than the rows need.
final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?

    /// The layout mode the SwiftUI view is showing, as the view itself reported it. It
    /// is the one input that changes the height the container must reserve (the grid
    /// carries a fourth row); the page does not, because the tallest page is reserved
    /// for the whole session. Carrying it on a callback retires the second transport
    /// this derivation used to have (a UserDefaults re-read at height time).
    private var layoutMode = KeyboardPreferences.layoutMode

    /// Which host field the keyboard is serving, as far as the proxy can identify one.
    ///
    /// The traits alone were not enough: two sibling fields with identical traits
    /// never changed the fingerprint, so a manual caps lock engaged in one followed the
    /// user into the next — the auto-derived state re-derives identically in both, but
    /// a MANUAL state is preserved by rule and leaked. `documentIdentifier` is the
    /// proxy's own notion of which document is being edited; iOS rotates it when focus
    /// moves between fields and holds it steady while one field is typed into.
    private struct FieldFingerprint: Equatable {
        let document: UUID?
        let returnKey: UIReturnKeyType
        let autocapitalization: UITextAutocapitalizationType
    }

    private var lastFingerprint: FieldFingerprint?

    /// Counters delivered into the SwiftUI view as plain values; `.onChange` on them is
    /// the controller-to-view channel. Reassigning `rootView` cannot touch the view's
    /// `@State` (see `refreshRoot`), but a changed `let` is exactly what it CAN deliver.
    private var fieldGeneration = 0
    private var hostTextGeneration = 0

    private var currentFingerprint: FieldFingerprint {
        FieldFingerprint(
            document: textDocumentProxy.documentIdentifier,
            returnKey: textDocumentProxy.returnKeyType ?? .default,
            autocapitalization: textDocumentProxy.autocapitalizationType ?? .sentences
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KeyPalette.fieldColor
        installKeyboardUI()

        // The vertical size class drives key height via KeyboardMetrics, so re-reserve
        // height whenever it changes (rotation, iPad multitasking).
        registerForTraitChanges([UITraitVerticalSizeClass.self]) { (controller: KeyboardViewController, _) in
            controller.applyHeight()
        }

        // Start the 50k-word once-parse before the view exists: viewDidLoad runs
        // ahead of onAppear, so this warm wins races the view's own warm can lose
        // on a cold launch.
        if KeyboardPreferences.glideTypingEnabled {
            Task.detached(priority: .utility) { _ = GlideLexicon.shared }
        }

        // Contact names and text replacements, folded into the glide lexicon.
        // Merged HERE, in the completion, not plumbed into the view: the view
        // reads its inputs in onAppear, which this async delivery normally
        // loses to — refreshRoot reassignment updates a `let` nobody re-reads
        // (see refreshRoot's doc comment). The detour off main matters: on a
        // cold launch this completion can arrive while the lexicon is still
        // unparsed, and touching `shared` on the main thread then blocks the
        // keyboard's slide-up for the whole parse. Force the once-parse on a
        // background task first; only the merge itself runs on the main actor.
        requestSupplementaryLexicon { lexicon in
            let words = lexicon.entries.map(\.documentText)
            Task.detached(priority: .userInitiated) {
                _ = GlideLexicon.shared
                await MainActor.run {
                    guard KeyboardPreferences.glideTypingEnabled else { return }
                    GlideLexicon.shared.merge(words: words)
                }
            }
        }
    }

    // Both are needed: viewWillAppear runs before the input view is sized, and
    // viewDidAppear is where needsInputModeSwitchKey is finally accurate.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncForAppearance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncForAppearance()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.applyHeight()
        })
    }

    private func syncForAppearance() {
        applyHeight()
        // Field switches can cross a dismiss/re-present boundary: the controller is
        // retained, so tapping a different field after dismissing the keyboard arrives
        // here, not at textDidChange. A blind seed swallowed exactly those switches and
        // let a manual caps lock (and the double-space window) leak into the new field.
        // First presentation stays a seed, not a switch.
        let fingerprint = currentFingerprint
        if let previous = lastFingerprint, previous != fingerprint {
            fieldGeneration += 1
        }
        lastFingerprint = fingerprint
        refreshRoot()
    }

    // MARK: - UI

    private func installKeyboardUI() {
        let host = UIHostingController(rootView: makeRootView())
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        // The Dynamic Type ceiling for the whole keyboard, applied to the trait
        // collection the hosting view hands SwiftUI. This is what the root view's
        // `@ScaledMetric` wrappers read; the `.dynamicTypeSize` modifier inside its
        // body only ever clamped the descendants, so at AX5 the Aa face resolved to
        // ~53pt inside a 43pt key while the key itself honoured the clamp.
        host.view.maximumContentSizeCategory = KeyboardMetrics.maximumContentSizeCategory
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        hostingController = host

        let height = view.heightAnchor.constraint(equalToConstant: preferredKeyboardHeight)
        height.priority = UILayoutPriority(999)
        heightConstraint = height

        NSLayoutConstraint.activate([
            height,
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func makeRootView() -> KeyboardRootView {
        KeyboardRootView(
            onInsert: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            onDeleteBackward: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            needsInputModeSwitchKey: needsInputModeSwitchKey,
            fieldGeneration: fieldGeneration,
            hostTextGeneration: hostTextGeneration,
            host: HostField(
                contextBefore: { [weak self] in
                    self?.textDocumentProxy.documentContextBeforeInput
                },
                contextAfter: { [weak self] in
                    self?.textDocumentProxy.documentContextAfterInput
                },
                returnKeyType: { [weak self] in
                    self?.textDocumentProxy.returnKeyType ?? .default
                },
                returnKeyEnabled: { [weak self] in
                    guard let proxy = self?.textDocumentProxy else { return true }
                    return !(proxy.enablesReturnKeyAutomatically ?? false) || proxy.hasText
                },
                autocapitalization: { [weak self] in
                    self?.textDocumentProxy.autocapitalizationType ?? .sentences
                },
                correctionAllowed: { [weak self] in
                    guard let proxy = self?.textDocumentProxy else { return false }
                    // Any one of these is the field saying "leave my text alone". A
                    // secure field first: iOS normally swaps to the system keyboard
                    // for one, but a host can leave this keyboard up, and a password
                    // is the one word that must never reach a spell checker.
                    if proxy.isSecureTextEntry == true { return false }
                    if proxy.autocorrectionType == .no { return false }
                    if proxy.spellCheckingType == .no { return false }
                    switch proxy.keyboardType {
                    case .some(.emailAddress), .some(.URL), .some(.numberPad),
                         .some(.phonePad), .some(.decimalPad), .some(.asciiCapableNumberPad):
                        return false
                    default:
                        return true
                    }
                },
                usesNumberPad: { [weak self] in
                    switch self?.textDocumentProxy.keyboardType {
                    case .some(.numberPad), .some(.phonePad), .some(.decimalPad),
                         .some(.asciiCapableNumberPad):
                        return true
                    default:
                        return false
                    }
                },
                hasFullAccess: { [weak self] in
                    self?.hasFullAccess ?? false
                }
            ),
            onLayoutModeChanged: { [weak self] mode in
                self?.layoutMode = mode
                self?.applyHeight()
            }
        )
    }

    /// Every host-side text change re-derives autocapitalization in the view: the host
    /// may have cleared its field (Messages after send) or the user moved the cursor,
    /// and deriving from here also picks up the *settled* proxy context after this
    /// keyboard's own edits. A changed fingerprint — a different field — additionally
    /// resets the per-field session state (shift provenance, the double-space window).
    ///
    /// Yes, this rebuilds the root view per keystroke. The rebuild is a value diff:
    /// letter keys compare Equatable inputs and skip repainting, so the cost is bounded,
    /// and it is the price of correctness — the earlier returnKeyType-only guard made
    /// shift state leak across every field whose return key happened to match.
    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        hostTextGeneration += 1
        let fingerprint = currentFingerprint
        if fingerprint != lastFingerprint {
            lastFingerprint = fingerprint
            fieldGeneration += 1
        }
        refreshRoot()
    }

    /// Reassigning rootView only propagates the values passed into `makeRootView` —
    /// notably `needsInputModeSwitchKey`. It cannot refresh the view's own `@State`,
    /// so do not add preference plumbing here expecting it to take effect.
    private func refreshRoot() {
        hostingController?.rootView = makeRootView()
    }

    // MARK: - Height

    private var preferredKeyboardHeight: CGFloat {
        // Derived from the same metrics the SwiftUI content uses, but deliberately NOT
        // from the current page: stock keyboards hold one height for the whole session,
        // and reserving per-page made ours grow 46pt on every tap of 123. Reserving the
        // tallest page up front costs a little headroom above the shorter ones and buys
        // a keyboard that never moves under the thumb.
        KeyboardMetrics.reservedHeight(
            mode: layoutMode,
            compact: traitCollection.verticalSizeClass == .compact
        )
    }

    private func applyHeight() {
        let target = preferredKeyboardHeight
        guard let heightConstraint, heightConstraint.constant != target else { return }
        heightConstraint.constant = target
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}
