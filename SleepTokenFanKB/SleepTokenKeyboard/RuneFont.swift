import CoreText
import UIKit
import SwiftUI

/// SleepTokenRunes.ttf — maps U+E900…U+E919 to traced ritual glyphs.
///
/// Registration is **once per process**. Re-registering logs
/// `GSFontRegisterCGFont failed 305` / “already exists” and is harmless but noisy.
enum RuneFont {
    /// Set after we have confirmed the face is usable (or after one register attempt).
    private static var didAttemptLoad = false

    static let familyName = "SleepTokenRunes"
    static let postScriptName = "SleepTokenRunes-Regular"
    static let fileName = "SleepTokenRunes"
    static let fileExtension = "ttf"

    static var fontURL: URL? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            return url
        }
        if let url = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExtension,
            subdirectory: "Resources"
        ) {
            return url
        }
        return Bundle.main
            .urls(forResourcesWithExtension: fileExtension, subdirectory: nil)?
            .first { $0.lastPathComponent == "\(fileName).\(fileExtension)" }
    }

    /// Whether a usable face is already in this process (no registration side effects).
    private static var isLoaded: Bool {
        UIFont(name: postScriptName, size: 12) != nil
            || UIFont(name: familyName, size: 12) != nil
    }

    /// True when SleepTokenRunes is available in this process (Rune Pad).
    static var isAvailableInProcess: Bool {
        ensureLoaded()
        return isLoaded
    }

    /// True when registered for other apps (device install). Simulator almost never.
    static var isInstalledSystemWide: Bool {
        for scope in [CTFontManagerScope.persistent, CTFontManagerScope.user] {
            guard let descs = CTFontManagerCopyRegisteredFontDescriptors(scope, true) as? [CTFontDescriptor]
            else { continue }
            for desc in descs {
                let family = CTFontDescriptorCopyAttribute(desc, kCTFontFamilyNameAttribute) as? String
                let ps = CTFontDescriptorCopyAttribute(desc, kCTFontNameAttribute) as? String
                if family == familyName || ps == postScriptName {
                    return true
                }
            }
        }
        return false
    }

    /// Idempotent. Safe to call from every view — only does work once.
    @discardableResult
    static func ensureLoaded() -> Bool {
        if didAttemptLoad {
            return isLoaded
        }
        didAttemptLoad = true

        // UIAppFonts (Info.plist) often already loaded the face — do nothing.
        if isLoaded {
            return true
        }

        // One-shot process registration. Ignore “already registered” (error 305).
        guard let url = fontURL else { return false }
        var error: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        // Do NOT also call CTFontManagerRegisterGraphicsFont — that is what spam-logs 305.

        return isLoaded
    }

    /// Back-compat alias used across the project.
    @discardableResult
    static func registerIfNeeded() -> Bool {
        ensureLoaded()
    }

    /// System-wide install (device). Not needed for Rune Pad; keyboard no longer depends on it.
    static func registerPersistentWithMessage() -> (Bool, String) {
        guard fontURL != nil else {
            return (false, "SleepTokenRunes.ttf missing from the app bundle.")
        }
        _ = ensureLoaded()

        #if targetEnvironment(simulator)
        return (
            true,
            "Simulator cannot install fonts for other apps. Rune Pad works with the in-app font; use Copy Image to share runes."
        )
        #else
        guard let url = fontURL else {
            return (false, "SleepTokenRunes.ttf missing from the app bundle.")
        }
        if isInstalledSystemWide {
            return (true, "Exact rune font is already available system-wide.")
        }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .persistent, &error)
        if ok || isInstalledSystemWide {
            return (
                true,
                "Font install requested. Accept the system sheet if shown, then reopen other apps."
            )
        }
        let detail = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "Unknown error"
        return (false, "System install failed: \(detail). Use Rune Pad → Copy Image instead.")
        #endif
    }

    @discardableResult
    static func registerPersistent() -> Bool {
        registerPersistentWithMessage().0
    }

    static func uiFont(size: CGFloat) -> UIFont {
        ensureLoaded()
        return UIFont(name: postScriptName, size: size)
            ?? UIFont(name: familyName, size: size)
            ?? .systemFont(ofSize: size)
    }

    static func font(size: CGFloat) -> Font {
        ensureLoaded()
        if isLoaded {
            return .custom(familyName, size: size)
        }
        return .system(size: size, design: .monospaced)
    }
}
