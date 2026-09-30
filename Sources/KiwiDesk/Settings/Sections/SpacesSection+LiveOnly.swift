import KiwiDeskCore
import SwiftUI

/// Settings ▸ Spaces' view-only rows (#1790): the Spaces the live
/// profile does not hold, after its own rows and the "+".
extension SpacesSection {
    /// The live Spaces the profile does not hold (#1790), after its
    /// own rows and the "+": temporary, then held. The LIVE page
    /// only — a stored profile's page is another arrangement.
    @ViewBuilder var liveOnlyRows: some View {
        if !model.editingStoredProfile {
            let temporary = model.liveOnlySpaces.filter(\.isTemporary)
            ForEach(temporary) { liveOnlyRow($0) }
            // Under the rows it explains, outside their grey.
            if !temporary.isEmpty, !temporary.contains(where: \.canAdd) {
                CrossReferenceRow(
                    prose: Self.noProfileProse,
                    linkTitle: SettingsDestination.profiles.title,
                    destination: .profiles
                )
            }
            ForEach(model.liveOnlySpaces.filter { !$0.isTemporary }) {
                liveOnlyRow($0)
            }
        }
    }

    private func liveOnlyRow(_ space: LiveOnlySpace) -> some View {
        LiveOnlySpaceRow(space: space) {
            model.core.addSpaceToProfile(space.id)
        }
    }
}
