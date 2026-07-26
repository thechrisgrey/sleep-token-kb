import UIKit
import SwiftUI

/// Custom keyboard: ritual or ABC keycaps; always inserts English letters.
final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?
    private var showNextKeyboardKey = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.secondarySystemBackground
        installKeyboardUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showNextKeyboardKey = needsInputModeSwitchKey
        applyHeight()
        refreshRoot()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showNextKeyboardKey = needsInputModeSwitchKey
        applyHeight()
        refreshRoot()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.applyHeight()
        })
    }

    private func installKeyboardUI() {
        let host = UIHostingController(rootView: makeRootView())
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        hostingController = host

        let height = NSLayoutConstraint(
            item: view!,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 0,
            constant: preferredKeyboardHeight
        )
        height.priority = UILayoutPriority(999)
        view.addConstraint(height)
        heightConstraint = height

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func makeRootView() -> KeyboardRootView {
        KeyboardRootView(
            proxy: textDocumentProxy,
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            needsInputModeSwitchKey: showNextKeyboardKey,
            onNeedsHeightUpdate: { [weak self] in
                self?.applyHeight()
                self?.refreshRoot()
            }
        )
    }

    private func refreshRoot() {
        hostingController?.rootView = makeRootView()
    }

    private var preferredKeyboardHeight: CGFloat {
        let bounds = view.bounds
        let screen = UIScreen.main.bounds
        let isLandscape = (bounds.width > 1 && bounds.height > 1)
            ? bounds.width > bounds.height
            : screen.width > screen.height

        let mode = KeyboardPreferences.layoutMode
        let hints = KeyboardPreferences.showLatinHints

        if isLandscape {
            return hints ? 210 : 190
        }
        switch (mode, hints) {
        case (.qwerty, false): return 280
        case (.qwerty, true): return 300
        case (.grid, false): return 320
        case (.grid, true): return 340
        }
    }

    private func applyHeight() {
        heightConstraint?.constant = preferredKeyboardHeight
        view.setNeedsUpdateConstraints()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}
