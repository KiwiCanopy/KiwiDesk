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
/// to reveal — the breadcrumb's back segment is the whole
/// navigation.
///
/// This chrome owns the header — the breadcrumb, the title, and
/// the active-layout reset (top-right, the destructive action that
/// concerns the rows below it) — while `SpaceOverrideRows` draws
/// the rows card and the dormant "saved for other layouts" card.
extension SpacesSection {
    @ViewBuilder
    func overridesEditor(_ space: SpaceID) -> some View {
        let mode = model.config.spaceModes[space] ?? .bsp
        let gates = SpacesGates(
            settings: model.config.settings,
            space: space,
            mode: mode
        )
        VStack(alignment: .leading, spacing: 0) {
            overridesBreadcrumb(space)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overridesHeader(space, mode: mode, gates: gates)
                    SpaceOverrideRows(
                        model: model,
                        space: space,
                        pendingResetAll: $pendingResetAll
                    )
                }
                // Bounded, not full-bleed: the override rows carry
                // their own label/control columns, so stretching
                // them to a wide pane only lengthens slider travel
                // past what the value needs. The side-by-side
                // preview (a later 8b turn) claims the space to the
                // right of this column.
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(
                    [.horizontal, .bottom],
                    SettingsMetrics.paneInset
                )
                .padding(.top, SettingsMetrics.paneInset)
            }
        }
    }

    /// `‹ Spaces › <space> › Overrides` — the first crumb is a
    /// standard `Button` back to the list, so it keeps focus,
    /// keyboard activation and VoiceOver for free; there is only
    /// one back target, since the per-space editor has no
    /// intermediate space page.
    private func overridesBreadcrumb(_ space: SpaceID) -> some View {
        HStack(spacing: 6) {
            Button {
                model.nav.spaceOverridesFocus = nil
            } label: {
                Label(
                    SettingsDestination.spaces.title,
                    systemImage: "chevron.backward"
                )
            }
            .buttonStyle(.borderless)
            crumbSeparator
            Text(space.raw)
                .foregroundStyle(.secondary)
            crumbSeparator
            Text(L("spaces.overrides.crumb", "Overrides"))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.callout)
        .lineLimit(1)
        .padding(.horizontal, SettingsMetrics.paneInset)
        .padding(.vertical, 10)
    }

    private var crumbSeparator: some View {
        Text(verbatim: "›").foregroundStyle(.tertiary)
    }

    /// The title and the active-layout reset. The reset lives here
    /// rather than in the footer (#678 8b): it acts on the rows
    /// directly below it, so it reads as their action; the dormant
    /// card's `Reset all…` stays with the *other* layouts it
    /// concerns.
    private func overridesHeader(
        _ space: SpaceID,
        mode: LayoutMode,
        gates: SpacesGates
    ) -> some View {
        let capacity = mode.overrideFieldCapacity
        let set = model.config.settings.overrideFieldCount(
            mode,
            for: space
        )
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(
                L(
                    "space_override.title",
                    "%1$@ — %2$@ overrides",
                    space.raw,
                    mode.displayName
                )
            )
            .font(.title2)
            .fontWeight(.semibold)
            // The active layout's set-vs-total fraction; Floating
            // has no override fields (capacity 0) so it shows none.
            if capacity > 0 {
                Text(
                    L(
                        "space_override.fraction",
                        "%1$d of %2$d set",
                        set,
                        capacity
                    )
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Spacer()
            resetActiveButton(space, mode: mode, gates: gates)
        }
    }

    private func resetActiveButton(
        _ space: SpaceID,
        mode: LayoutMode,
        gates: SpacesGates
    ) -> some View {
        let reason = gates.inertReason(
            for: .spaces(.spaceOverrideResetActive)
        )
        return Button(
            L(
                "space_override.reset_active",
                "Reset %1$@ Overrides",
                mode.displayName
            ),
            role: .destructive
        ) {
            model.config.settings.resetOverride(mode, for: space)
        }
        .buttonStyle(.bordered)
        // "Grey, don't hide" (§2.7): the reset is furniture of the
        // active section, greyed when the layout has nothing to
        // reset, with the reason on hover.
        .disabled(reason != nil)
        .help(reason.map(SpacesGateHelp.sentence) ?? "")
    }
}
