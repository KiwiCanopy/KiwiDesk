import AppKit
import KiwiDeskCore
import SwiftUI

/// AppKit appearance rendering for `AppearanceChoice` (#96, #678).
extension AppearanceChoice {
    /// Maps choice to `NSAppearance` (nil delegates to macOS).
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    /// Applies this choice to `NSApp.appearance` across all windows (#678).
    @MainActor
    func apply() {
        NSApp.appearance = nsAppearance
    }

    /// Localized display label for the appearance picker.
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
