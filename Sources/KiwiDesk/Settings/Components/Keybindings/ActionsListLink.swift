import AppKit
import KiwiDeskCore
import SwiftUI

/// The Lua bindings drawer's pointer at the generated actions page
/// (#2610), so the place a user binds a non-catalog action names
/// where the actions are. `LinkedCaption` for the pointing-hand
/// cursor, as `GuideLink`.
struct ActionsListLink: View {
    var body: some View {
        let parts = LinkedCaption.split(frame: Self.prose)
        LinkedCaption(
            leading: parts.0,
            linkTitle: Self.label,
            trailing: parts.1,
            navigate: Self.open
        )
    }

    @MainActor static var prose: String {
        L(
            "shortcuts.advanced.actions_hint",
            "Every action a key can run is in %1$@."
        )
    }

    /// The link's noun; the sentence carries the verb.
    @MainActor static var label: String {
        L("shortcuts.advanced.actions_link", "the actions list")
    }

    @MainActor static func open() {
        NSWorkspace.shared.open(SupportLinks.actions)
    }
}
