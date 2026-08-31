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

/// Standard "lives elsewhere" row embedding a linked destination inline
/// (`localization.md`, `CrossReferenceRowSlotTests`, `LinkedCaption`).
struct CrossReferenceRow: View {
    /// Formatted sentence carrying ``linkSlot`` for destination placement.
    let prose: String
    let linkTitle: String
    let destination: SettingsDestination
    @Environment(\.settingsNavigate) private var navigate

    /// Unicode U+FFFC replacement character used as the link slot token.
    static let linkSlot = "\u{FFFC}"

    var body: some View {
        let (leading, trailing) = split
        LinkedCaption(
            leading: leading,
            linkTitle: linkTitle,
            trailing: trailing,
            navigate: { navigate(destination) }
        )
    }

    /// Splits prose around `linkSlot` (`CrossReferenceRowSlotTests`,
    /// `placeholder_drift`).
    private var split: (String, String) {
        guard let slot = prose.range(of: Self.linkSlot) else {
            assertionFailure("cross-reference prose has no slot")
            return (prose + " ", "")
        }
        return (
            String(prose[..<slot.lowerBound]),
            String(prose[slot.upperBound...])
        )
    }
}
