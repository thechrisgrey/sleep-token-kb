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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KeyPalette.fieldColor
        installKeyboardUI()
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

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        // The vertical size class drives key height via KeyboardMetrics.
        if previous?.verticalSizeClass != traitCollection.verticalSizeClass {
            applyHeight()
        }
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
            onHeightInputsChanged: { [weak self] page in
                self?.currentPage = page
                self?.applyHeight()
            }
        )
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
