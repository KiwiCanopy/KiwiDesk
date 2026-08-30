import KiwiDeskCore
import SwiftUI

/// Detail panel previewing resolved layout for spaces (#794).
///
/// Draws schematic via `TilingSettings.resolved(for:activeMode:)` (#702).
struct SpacesPanelPreview: View {
    @ObservedObject var model: SettingsModel
    @State private var selected: SpaceID?
    @State private var windows = LayoutSchematic.defaultWindowCount

    private var spaces: [SpaceID] { model.config.spaces }

    /// Currently displayed space adhering to editor focus precedence.
    var shownSpace: SpaceID? { space }

    /// Selects a space, routing through open override editor if present.
    func pick(_ candidate: SpaceID) {
        if model.nav.spaceOverridesFocus != nil {
            model.nav.spaceOverridesFocus = candidate
        }
        selected = candidate
    }

    private var space: SpaceID? {
        if let focus = model.nav.spaceOverridesFocus,
            spaces.contains(focus)
        {
            return focus
        }
        if let selected, spaces.contains(selected) { return selected }
        return spaces.first
    }

    private func mode(of space: SpaceID) -> LayoutMode {
        model.config.spaceModes[space] ?? .bsp
    }

    var body: some View {
        SettingsSection(SettingsCatalog.spaces.spacePreview) {
            if let space {
                chips
                scene(for: space)
                if drawsSchematic(for: space) {
                    caption(for: space)
                    countRow
                }
            } else {
                Text(
                    L(
                        "spaces.preview.none",
                        "No Spaces in this draft yet."
                    )
                )
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
            }
        }
    }

    // MARK: - The chip row

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(spaces, id: \.raw) { candidate in
                    chip(candidate)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ candidate: SpaceID) -> some View {
        let isOn = candidate == space
        return Button {
            pick(candidate)
        } label: {
            Text(candidate.raw)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(
                            SettingsTheme.accent
                                .opacity(isOn ? 0.22 : 0.08)
                        )
                )
                .overlay(
                    Capsule().strokeBorder(
                        SettingsTheme.accent
                            .opacity(isOn ? 0.7 : 0.25),
                        lineWidth: isOn ? 1.5 : 1
                    )
                )
                .foregroundStyle(SettingsTheme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            isOn ? [.isButton, .isSelected] : .isButton
        )
    }

    // MARK: - The scene

    /// Whether layout renders a schematic (`SpacesPanelSelectionTests`).
    func drawsSchematic(for space: SpaceID) -> Bool {
        LayoutMode.placementTabs.contains(mode(of: space))
    }

    @ViewBuilder
    private func scene(for space: SpaceID) -> some View {
        let mode = mode(of: space)
        if drawsSchematic(for: space) {
            LayoutSchematicView(
                mode: mode,
                settings: model.config.settings.resolved(
                    for: space,
                    activeMode: mode
                ),
                windows: windows,
                scale: .panel
            )
        } else {
            Text(
                L(
                    "space_override.floating.none",
                    "Floating has no per-Space overrides."
                )
            )
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink3)
        }
    }

    // MARK: - The caption

    /// Caption describing override status (#818).
    private func caption(for space: SpaceID) -> some View {
        let mode = mode(of: space)
        let n = overrideCount(for: space)
        return Text(
            n == 0
                ? L(
                    "spaces.preview.caption_default",
                    "%1$@ — follows %2$@.",
                    mode.displayName,
                    SettingsDestination.layoutDefaults.title
                )
                : L(
                    "spaces.preview.caption_overridden",
                    "%1$@ — settings overridden for this "
                        + "Space: %2$d",
                    mode.displayName,
                    n
                )
        )
        .font(.caption)
        .foregroundStyle(SettingsTheme.ink3)
    }

    /// Count of active layout overrides on space (`SpacesPanelPreviewTests`).
    func overrideCount(for space: SpaceID) -> Int {
        let mode = mode(of: space)
        guard mode != .floating else { return 0 }
        return model.config.settings.overrideFieldCount(
            mode,
            for: space
        )
    }

    // MARK: - The window count

    private var countRange: ClosedRange<Double> {
        let band = LayoutSchematic.windowCountRange
        return Double(band.lowerBound)...Double(band.upperBound)
    }

    /// Preview window count slider.
    private var countRow: some View {
        HStack(spacing: 8) {
            Text(
                L("layout_defaults.preview_windows", "Window count")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            SettingsSlider(
                value: Binding(
                    get: { Double(windows) },
                    set: { windows = Int($0.rounded()) }
                ),
                range: countRange,
                step: 1,
                label: L(
                    "layout_defaults.preview_windows",
                    "Window count"
                ),
                spokenValue: "\(windows)"
            )
            .accessibilityHint(
                L(
                    "spaces.preview.count_hint",
                    "Changes this preview only; it is not saved."
                )
            )
            Text("\(windows)")
                .frame(width: 24, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.caption.monospacedDigit())
                .settingsReadout()
        }
    }
}
