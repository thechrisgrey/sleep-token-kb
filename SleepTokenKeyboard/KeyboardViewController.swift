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

    /// Which page the SwiftUI view is showing. The view reports it up, because the page
    /// changes the row count and therefore the height the container must reserve.
    private var currentPage: KeyboardMetrics.Page = .letters

    /// Last seen return key type, used to notice a field change without rebuilding the
    /// view on every keystroke. See `textDidChange`.
    private var lastReturnKeyType: UIReturnKeyType?

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
            host: HostField(
                contextBefore: { [weak self] in
                    self?.textDocumentProxy.documentContextBeforeInput
                },
                returnKeyType: { [weak self] in
                    self?.textDocumentProxy.returnKeyType ?? .default
                },
                autocapitalization: { [weak self] in
                    self?.textDocumentProxy.autocapitalizationType ?? .sentences
                },
                hasFullAccess: { [weak self] in
                    self?.hasFullAccess ?? false
                }
            ),
            onHeightInputsChanged: { [weak self] page in
                self?.currentPage = page
                self?.applyHeight()
            }
        )
    }

    /// Rebuild only when the *field* changes, never per keystroke.
    ///
    /// `textDidChange` fires on every insert, and rebuilding the root view there would
    /// throw away a frame's work on each tap. The return key title is the only thing in
    /// the view that depends on which field is focused, so its type is the cheapest
    /// available proxy for "the user moved to a different field".
    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        let current = textDocumentProxy.returnKeyType
        guard current != lastReturnKeyType else { return }
        lastReturnKeyType = current
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
            page: currentPage,
            mode: KeyboardPreferences.layoutMode,
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
