import UIKit
import SwiftUI

/// Principal class for the Custom Keyboard extension.
/// Appears under Settings → General → Keyboard → Keyboards after the host app is installed.
final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.secondarySystemBackground
        installKeyboardUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeight()
        hostingController?.rootView = makeRootView()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateHeight()
        })
    }

    override func textDidChange(_ textInput: (any UITextInput)?) {
        // Could refresh shift state from proxy autocapitalization if desired.
    }

    // MARK: - UI

    private func installKeyboardUI() {
        let root = makeRootView()
        let host = UIHostingController(rootView: root)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let height = view.heightAnchor.constraint(equalToConstant: preferredKeyboardHeight)
        height.priority = .defaultHigh
        height.isActive = true
        heightConstraint = height

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController = host
    }

    private func makeRootView() -> KeyboardRootView {
        KeyboardRootView(
            proxy: textDocumentProxy,
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            needsInputModeSwitchKey: needsInputModeSwitchKey,
            onLayoutModeChange: { [weak self] _ in
                self?.updateHeight(rebuild: false)
            }
        )
    }

    private var preferredKeyboardHeight: CGFloat {
        let bounds = view.bounds
        let isLandscape = bounds.width > 0
            ? bounds.width > bounds.height
            : UIScreen.main.bounds.width > UIScreen.main.bounds.height
        // Grid needs a bit more vertical room than QWERTY.
        let mode = KeyboardPreferences.layoutMode
        switch (isLandscape, mode) {
        case (true, .qwerty): return 180
        case (true, .grid): return 200
        case (false, .qwerty): return 260
        case (false, .grid): return 300
        }
    }

    private func updateHeight(rebuild: Bool = true) {
        heightConstraint?.constant = preferredKeyboardHeight
        if rebuild {
            hostingController?.rootView = makeRootView()
        }
    }
}
