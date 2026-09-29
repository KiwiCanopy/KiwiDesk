import KiwiDeskCore
import SwiftUI

/// The line at the top of a page whose settings belong to a look
/// (#1752) — Advanced Colors, KiwiShelf & Bars, Gaps & Borders —
/// saying whether an edit here reaches other profiles, and linking
/// to the switch. Shown only where another saved profile exists,
/// since with one there is nothing to reach; the page's rows that
/// are never part of a look are not claimed, the sentence naming
/// the look rather than the page.
struct SharedLookPointer: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        if let follows {
            CrossReferenceRow(
                prose: follows ? Self.sharedProse : Self.ownProse,
                linkTitle: Self.linkTitle,
                destination: .looks
            )
        }
    }

    /// Whether the page's profile follows the shared look; nil
    /// where the line says nothing.
    private var follows: Bool? {
        guard model.guiManaged,
            model.profileSummaries.count > 1,
            let edited = model.editingProfile ?? model.activeProfile
        else { return nil }
        return model.lookFollows[edited]
    }

    static var sharedProse: String {
        L(
            "looks.shared.pointer",
            "These settings are part of the shared look — choose "
                + "which profiles use it in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    static var ownProse: String {
        L(
            "looks.own.pointer",
            "These settings are part of this profile's own look — "
                + "share it in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    /// Built from the two titles it names, so neither can go
    /// stale beside a copy.
    static var linkTitle: String {
        L(
            "looks.shared.xref_link",
            "%1$@ ▸ %2$@",
            SettingsDestination.looks.title,
            SettingsCatalog.colors.sharedLook.text
        )
    }
}
