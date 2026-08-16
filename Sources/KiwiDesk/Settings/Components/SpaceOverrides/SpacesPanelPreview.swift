import KiwiDeskCore
import SwiftUI

/// Spaces & Layouts' detail panel (#794): click through the
/// draft's Spaces and see each one's layout as that Space
/// actually resolves it.
///
/// The area lists every Space with its layout picker, and until
/// now seeing what a Space's layout *looks like* — with its own
/// overrides applied — meant leaving for Layout Defaults, whose
/// preview draws the defaults rather than this Space. The
/// overrides are exactly what the reader came to check, so that
/// journey answered the wrong question.
///
/// The schematic is fed `TilingSettings.resolved(for:activeMode:)`
/// — the engine's own per-space resolver, the one a real retile
/// asks — rather than a resolution rule re-derived beside the
/// drawing (gui.md, #702). `SpaceOverridePreview` already worked
/// this way inside the per-space editor and said in its own
/// docstring that it was awaiting this rework; the panel is that
/// rework, and the difference is that this one is reachable
/// without opening a Space's editor at all.
struct SpacesPanelPreview: View {
    @ObservedObject var model: SettingsModel
    /// Which Space the panel is drawing. Panel state, not the
    /// draft: choosing what to LOOK at is a question asked of the
    /// preview, exactly like the window count below.
    @State private var selected: SpaceID?
    @State private var windows = LayoutSchematic.defaultWindowCount

    private var spaces: [SpaceID] { model.config.spaces }

    /// The drawn Space, in precedence order: the one whose
    /// override editor is OPEN, then the chip the reader picked,
    /// then the first.
    ///
    /// The editor wins because it is the stronger statement of
    /// intent — someone editing Space 3's overrides is asking
    /// about Space 3, and a panel showing Space 1 beside those
    /// rows would be answering a question nobody asked. It is
    /// also what lets the editor give up its own copy of this
    /// preview (#794): one screen must not state one fact twice,
    /// and the panel can only take that over if it follows the
    /// row being edited.
    ///
    /// Every arm re-checks membership, so deleting a Space in the
    /// draft can never leave the panel drawing one that is gone.
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
                caption(for: space)
                countRow
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

    /// One chip per Space in the draft. Buttons, not decorated
    /// `Text`: this is the panel's only control besides the
    /// slider, so it earns a name, keyboard activation and a
    /// spoken selected state — a styled label would announce
    /// nothing and be unreachable without a pointer.
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
            selected = candidate
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
        // The chip's own text is its name; the selected state is
        // a TRAIT rather than a second spoken sentence, so the
        // rotor reads "Space 2, selected" and not a duplicated
        // label (`gui.md` ▸ naming a control replaces what it
        // announced).
        .accessibilityAddTraits(
            isOn ? [.isButton, .isSelected] : .isButton
        )
    }

    // MARK: - The scene

    @ViewBuilder
    private func scene(for space: SpaceID) -> some View {
        let mode = mode(of: space)
        if LayoutMode.placementTabs.contains(mode) {
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
            // Floating has no schematic anywhere in the tree, and
            // an empty plate would read as a drawing that failed
            // rather than as a layout that places nothing.
            Text(
                L(
                    "spaces.preview.floating",
                    "Floating places no windows, so there is "
                        + "nothing to draw."
                )
            )
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink3)
        }
    }

    // MARK: - The caption

    /// Names the layout, and whether this Space departs from it.
    ///
    /// The count goes LAST behind a label, so no locale has to
    /// agree with a number mid-sentence (`localization.md` ▸ a
    /// frame interpolating a COUNT) — which is also why the
    /// two arms are separate keys rather than one frame with an
    /// argument that may render empty.
    private func caption(for space: SpaceID) -> some View {
        let mode = mode(of: space)
        let n = overrideCount(for: space)
        return Text(
            n == 0
                ? L(
                    "spaces.preview.caption_default",
                    "%1$@ — follows the layout defaults.",
                    mode.displayName
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

    /// How many of the active layout's settings this Space
    /// overrides — **derived, never a hand-listed field list.**
    ///
    /// Encodes the global settings and this Space's resolved
    /// settings and counts the leaves that differ under the
    /// active mode's own key. A hand-mirrored list of overridable
    /// fields would be a third copy of a field list the engine
    /// and the editor already carry, and past two mirrors
    /// `parity-tests.md` asks for a forget-proof derivation
    /// instead — this is that derivation, so a new overridable
    /// field counts here the day it exists.
    ///
    /// Internal so `SpacesPanelPreviewTests` reads the number: a
    /// caption that says "2" while the resolver disagrees is
    /// exactly the drift a source scan cannot see.
    func overrideCount(for space: SpaceID) -> Int {
        let mode = mode(of: space)
        guard mode != .floating else { return 0 }
        let resolved = model.config.settings.resolved(
            for: space,
            activeMode: mode
        )
        return TilingSettingsDiff.changedLeaves(
            from: model.config.settings,
            to: resolved,
            under: "layout.\(mode.rawValue)"
        )
    }

    // MARK: - The window count

    private var countRange: ClosedRange<Double> {
        let band = LayoutSchematic.windowCountRange
        return Double(band.lowerBound)...Double(band.upperBound)
    }

    /// A preview control, not a setting — it never enters the
    /// draft. Said in the label rather than left to be inferred:
    /// a slider in a panel that changes nothing is otherwise
    /// indistinguishable from one that does.
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
                step: 1
            )
            .accessibilityLabel(
                L("layout_defaults.preview_windows", "Window count")
            )
            .accessibilityValue("\(windows)")
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
                .accessibilityHidden(true)
        }
    }
}
