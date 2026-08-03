import KiwiDeskCore
import SwiftUI

/// The GUI half of the appearance pick (#678 item 8).
///
/// Core owns the CHOICE and this owns its rendering, which is the
/// #96 seam applied to a value type: `AppearanceChoice` is a case
/// with no AppKit in it, and the mapping onto SwiftUI's optional
/// `ColorScheme` lives where SwiftUI does.
extension AppearanceChoice {
    /// `nil` means "let macOS decide", which is what
    /// `.preferredColorScheme(nil)` does — NOT a light default.
    /// The distinction is the whole feature: a `.system` that
    /// resolved to a concrete scheme would stop following the
    /// system the moment the user flipped it.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
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
