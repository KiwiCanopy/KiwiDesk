import AppKit
import KiwiDeskCore
import SwiftUI

/// The GUI half of the appearance pick (#678 item 8).
///
/// Core owns the CHOICE and this owns its rendering, which is the
/// #96 seam applied to a value type: `AppearanceChoice` is a case
/// with no AppKit in it, and the mapping onto AppKit lives where
/// AppKit does.
extension AppearanceChoice {
    /// The application-wide appearance. `nil` means "let macOS
    /// decide" — NOT a light default. That distinction is the
    /// whole feature: a `.system` resolved to a concrete
    /// appearance would stop following the system the moment the
    /// user flipped it.
    ///
    /// **Applied to `NSApp`, not through
    /// `.preferredColorScheme`.** The SwiftUI modifier sets the
    /// HOSTING WINDOW's appearance, which fails this feature two
    /// ways. It is too narrow — item 8 asks that every screen
    /// have a dark counterpart, and the bars and border overlays
    /// are their own windows that a Settings-view modifier never
    /// reaches. And it does not cleanly revert: AppKit-backed
    /// subviews (`NSViewRepresentable` captions, the
    /// visual-effect sidebar) resolve their appearance when they
    /// are made and do not re-read it when the modifier returns
    /// to `nil`, so Dark → System stranded them dark while
    /// Dark → Light — a new concrete value — looked fine.
    /// Reported on device before this shipped.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    /// Applies this choice to the running application.
    ///
    /// Assigning `NSApp.appearance = nil` is what hands the
    /// decision back to macOS, and AppKit propagates it to every
    /// window — which is why this is a one-liner rather than a
    /// per-window sweep that would need to know about windows
    /// opened later.
    @MainActor
    func apply() {
        NSApp.appearance = nsAppearance
    }

    /// The choice's menu-item text. One call site per key, which
    /// is what `scripts/extract-keys` reads — a parallel
    /// `labelKey` property would be a second copy of these three
    /// strings and would drift from them.
    @MainActor
    var label: String {
        switch self {
        case .system:
            return L("general.appearance.system", "System")
        case .light:
            return L("general.appearance.light", "Light")
        case .dark:
            return L("general.appearance.dark", "Dark")
        }
    }
}
