import KiwiDeskCore
import SwiftUI

/// The draft writes both Space row lists share (#2737).
extension SettingsModel {
    /// Removes `space` from the draft, and its overrides editor
    /// if that was open on it.
    func removeSpace(_ space: SpaceID) {
        config.removeSpace(space)
        if nav.spaceOverridesFocus == space {
            nav.spaceOverridesFocus = nil
        }
    }

    /// A Space's icon in the draft, the empty string for none.
    func spaceIconBinding(_ space: SpaceID) -> Binding<String> {
        Binding(
            get: { self.config.settings.spaceIcons[space] ?? "" },
            set: {
                self.config.settings.spaceIcons[space] =
                    $0.isEmpty ? nil : $0
            }
        )
    }

    /// What the Space Bar draws for `space` with no icon: its
    /// digits, or its monogram (`KiwiCore.spaceIdentifier`).
    func spaceIdentifierText(_ space: SpaceID) -> String? {
        if case .text(let text, _) = KiwiCore.spaceIdentifier(
            id: space,
            icon: nil
        ) {
            return text
        }
        return nil
    }
}
