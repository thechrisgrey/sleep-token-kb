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

    /// What the SwiftUI view is showing, as the view itself reported it. The page and
    /// layout mode change the row count and therefore the height the container must
    /// reserve; carrying both on the one callback retires the second transport this
    /// derivation used to have (a UserDefaults re-read at height time).
    private var heightInputs = KeyboardMetrics.HeightInputs(
        page: .letters,
        mode: KeyboardPreferences.layoutMode
    )

    /// Which host field the keyboard is serving, as far as the proxy can identify one.
    /// Two fields with identical traits are indistinguishable, and that is acceptable:
    /// identical traits mean identical derivation rules, so the per-field reset only
    /// matters when the fingerprint actually changes.
    private struct FieldFingerprint: Equatable {
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
        // Seed the fingerprint so the first textDidChange after presentation is not
        // mistaken for a field switch (the audit's guaranteed-redundant rebuild).
        lastFingerprint = currentFingerprint
        refreshRoot()
    }

    // MARK: - UI

    private func installKeyboardUI() {
        let host = UIHostingController(rootView: makeRootView())
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
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
                hasFullAccess: { [weak self] in
                    self?.hasFullAccess ?? false
                }
            ),
            onHeightInputsChanged: { [weak self] inputs in
                self?.heightInputs = inputs
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
        // Derived from the same metrics the SwiftUI content uses. Reserve the tallest
        // key style for the current page so toggling rune/ABC never clips a visible row.
        KeyboardMetrics.maxContentHeight(
            page: heightInputs.page,
            mode: heightInputs.mode,
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
