import KiwiDeskCore
import SwiftUI

/// Pushed per-space override editor (#678 8b, #205, #326, #794).
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
                    overridesBody(space, mode: mode, gates: gates)
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
            }
        }
    }

    /// Override rows and reset button (owner 2026-08-16, #291, #794).
    @ViewBuilder
    private func overridesBody(
        _ space: SpaceID,
        mode: LayoutMode,
        gates: SpacesGates
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                SpaceOverrideRows(
                    model: model,
                    space: space,
                    pendingResetAll: $pendingResetAll
                )
                .frame(maxWidth: 700, alignment: .leading)
                .layoutPriority(1)
            }
            resetActiveButton(space, mode: mode, gates: gates)
        }
    }

    /// Breadcrumb navigation with back button (#678 Phase 4 turn 20a).
    private func overridesBreadcrumb(_ space: SpaceID) -> some View {
        HStack(spacing: 6) {
            Button {
                returningRow = space
                model.nav.spaceOverridesFocus = nil
            } label: {
                Label(
                    SettingsDestination.spaces.title,
                    systemImage: "chevron.backward"
                )
            }
            .focused($overridesBackFocused)
            .buttonStyle(.borderless)
            .neutralButtonLabel()
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
        .onAppear { overridesBackFocused = true }
    }

    private var crumbSeparator: some View {
        Text(verbatim: "›").foregroundStyle(.tertiary)
    }

    /// Header with title and active layout fraction (#678 8b).
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
        .disabled(reason != nil)
        .help(reason.map(SpacesGateHelp.sentence) ?? "")
    }
}
