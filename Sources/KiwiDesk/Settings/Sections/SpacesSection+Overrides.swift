import KiwiDeskCore
import SwiftUI

/// The pushed per-space override editor (#678 8b), replacing the
/// #205 Customize popover. The popover capped the editing surface
/// at 392 pt — "the app's narrowest editing surface," by its own
/// docstring — which a side-by-side live preview cannot fit; the
/// full pane can. This is a view-state branch of `SpacesSection`
/// driven by `model.nav.spaceOverridesFocus`, not a
/// `SettingsSurface`: the override controls are per-space and
/// uncataloged, so there is nothing for search or the #326 bridge
/// to reveal — the back affordance below is the whole navigation.
extension SpacesSection {
    @ViewBuilder
    func overridesEditor(_ space: SpaceID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            overridesBackBar
            Divider()
            ScrollView {
                SpaceOverrideRows(
                    model: model,
                    space: space,
                    pendingResetAll: $pendingResetAll
                )
                // Bounded, not full-bleed: the override rows carry
                // their own label/control columns, so stretching
                // them to a wide pane only lengthens slider travel
                // past what the value needs. Cap the column, then
                // left-align it in the full pane — the side-by-side
                // preview (a later 8b turn) claims the space to the
                // right of this column.
                .frame(maxWidth: 520, alignment: .leading)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(
                    [.horizontal, .bottom],
                    SettingsMetrics.paneInset
                )
                .padding(.top, SettingsMetrics.paneInset)
            }
        }
    }

    /// A single back affordance to the space list. A standard
    /// `Button`, so it keeps focus, keyboard activation and
    /// VoiceOver for free; the pane's own header bar already names
    /// the destination, so this names the parent surface it
    /// returns to rather than repeating it.
    private var overridesBackBar: some View {
        HStack {
            Button {
                model.nav.spaceOverridesFocus = nil
            } label: {
                Label(
                    L("spaces.overrides.back", "All spaces"),
                    systemImage: "chevron.backward"
                )
            }
            .buttonStyle(.borderless)
            Spacer()
        }
        .padding(.horizontal, SettingsMetrics.paneInset)
        .padding(.vertical, 10)
    }
}
