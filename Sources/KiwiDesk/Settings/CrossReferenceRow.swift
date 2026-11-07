import SwiftUI

/// Cross-tab navigation row for settings detail pane.

private struct SettingsNavigateKey: EnvironmentKey {
    static let defaultValue: @MainActor (SettingsDestination) -> Void = { _ in
    }
}

extension EnvironmentValues {
    /// Jumps the settings window to a sidebar destination.
    var settingsNavigate: @MainActor (SettingsDestination) -> Void
    {
        get { self[SettingsNavigateKey.self] }
        set { self[SettingsNavigateKey.self] = newValue }
    }
}

private struct SettingsLandKey: EnvironmentKey {
    static let defaultValue: @MainActor (SettingsAnchor) -> Void = { _ in
    }
}

extension EnvironmentValues {
    /// Lands the settings window on one row, through the model's
    /// one `land(on:)` (#3062).
    var settingsLand: @MainActor (SettingsAnchor) -> Void {
        get { self[SettingsLandKey.self] }
        set { self[SettingsLandKey.self] = newValue }
    }
}

/// Standard "lives elsewhere" row embedding a linked destination inline
/// (`localization.md`, `CrossReferenceRowSlotTests`, `LinkedCaption`).
struct CrossReferenceRow: View {
    /// Formatted sentence carrying ``linkSlot`` for destination placement.
    let prose: String
    let linkTitle: String
    let destination: SettingsDestination
    /// The row on `destination` to land on and flash, or nil for its
    /// root (#3062).
    var row: String? = nil
    @Environment(\.settingsNavigate) private var navigate
    @Environment(\.settingsLand) private var land

    /// Unicode U+FFFC replacement character used as the link slot token.
    static let linkSlot = "\u{FFFC}"

    var body: some View {
        let (leading, trailing) = Self.split(prose)
        LinkedCaption(
            leading: leading,
            linkTitle: linkTitle,
            trailing: trailing,
            navigate: {
                if let row {
                    land(
                        SettingsAnchor(destination: destination, anchor: row)
                    )
                } else {
                    navigate(destination)
                }
            }
        )
    }

    /// Splits prose around `linkSlot` (`CrossReferenceRowSlotTests`,
    /// `placeholder_drift`); the Mac Checklist's captions take it
    /// for their System Settings link too.
    static func split(_ prose: String) -> (String, String) {
        guard let slot = prose.range(of: linkSlot) else {
            assertionFailure("cross-reference prose has no slot")
            return (prose + " ", "")
        }
        return (
            String(prose[..<slot.lowerBound]),
            String(prose[slot.upperBound...])
        )
    }
}
