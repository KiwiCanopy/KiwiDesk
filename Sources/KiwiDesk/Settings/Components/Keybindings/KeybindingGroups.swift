import KiwiDeskCore
import SwiftUI

/// The Shortcuts action groups (#678 Phase 3, turn 5), rendered
/// FROM the settings census: `ShortcutsRowOrder` gives the
/// families in display order, `ShortcutsFamilyRows` expands each
/// into its rows, and `ShortcutsCensusRenderTests` pins both
/// against the census. Adding a keybinding family to the census
/// therefore fails the guard until it is placed in an order list,
/// and fails to compile until it is given an expansion.
///
/// Flat titled sections, one level of hierarchy — Focus, Move
/// windows, Size & float, Switch layers (the old double-nested
/// disclosures are gone). Space rows generate from the defined
/// spaces, so adding a space adds its commands. Recording upserts
/// a `.navigation` row keyed by its Lua; clearing removes it.

/// One census family's rows, plus the sub-heading and caption a
/// family carries when its rows need naming as a block.
///
/// The heading belongs to the FAMILY, not to the container, which
/// is why it is resolved from the key rather than written into
/// each group: the census is what says a family exists, so a
/// family gains its heading with its rows.
struct KeybindingFamilyRows: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let key: SettingKey
    let expander: ShortcutsFamilyRows

    var body: some View {
        let commands = renderedRows
        if !commands.isEmpty {
            if let heading = ShortcutsFamilyHeading.title(for: key) {
                Text(heading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            if let caption = ShortcutsFamilyHeading.caption(
                for: key
            ) {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(commands) { command in
                NavRow(
                    model: model,
                    bindings: $bindings,
                    command: command
                )
            }
        }
    }

    private var renderedRows: [NavCommand] {
        expander.renderedRows(for: key)
    }
}

/// The block headings and captions a family carries above its
/// rows. Only some families have one: four directional rows read
/// fine under the container title, while a per-space block needs
/// saying what the repetition is.
@MainActor
enum ShortcutsFamilyHeading {
    static func title(for key: SettingKey) -> String? {
        switch key {
        case .shortcuts(.goToSpace):
            return L("shortcuts.go_to_space", "Go to space")
        case .shortcuts(.moveWindowToTrack):
            return L("shortcuts.move_to_track", "Move to track")
        case .shortcuts(.moveToSpace):
            return L("shortcuts.move_to_space", "Move to space")
        default:
            return nil
        }
    }

    /// Track authoring rows are always rendered — no gate (#188).
    /// The caption tells newcomers these only matter in the track
    /// layout, so unbound rows in another layout don't read as
    /// broken.
    static func caption(for key: SettingKey) -> String? {
        switch key {
        case .shortcuts(.moveWindowToTrack):
            return L(
                "shortcuts.move_to_track.caption",
                "Only relevant if you're using the track "
                    + "layout."
            )
        default:
            return nil
        }
    }
}

struct FocusGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.focusKeys) {
            ForEach(ShortcutsRowOrder.focusAtRest, id: \.id) {
                key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
        }
    }
}

struct MoveWindowsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(
            SettingsCatalog.shortcuts.moveWindows
        ) {
            ForEach(
                ShortcutsRowOrder.moveWindowsAtRest,
                id: \.id
            ) { key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
        }
    }
}

/// Size & float (#68 §3.5): the per-axis Grow/Shrink rows (#56)
/// and the state toggles, with the unsupported-resize cue (#184)
/// behind the card's disclosure — the census tiers it
/// `.showMore`, being the one row here that is a preference
/// rather than a binding.
struct SizeFloatGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows
    @State private var moreExpanded = false

    var body: some View {
        SettingsSection(
            SettingsCatalog.shortcuts.sizeFloat
        ) {
            ForEach(
                ShortcutsRowOrder.sizeAndFloatAtRest,
                id: \.id
            ) { key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
            Text(sizeFloatCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            moreDisclosure
        }
    }

    private var moreDisclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.shortcuts.sizeFloatMore,
            chrome: .inline(font: .subheadline),
            isExpanded: $moreExpanded,
            scrollHoisted: true
        ) {
            ForEach(
                ShortcutsRowOrder.sizeAndFloatMore,
                id: \.id
            ) { key in
                moreRow(key)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder private func moreRow(
        _ key: SettingKey
    ) -> some View {
        switch key {
        case .behaviour(.resizeFeedback):
            Toggle(
                L(
                    "shortcuts.size_float.feedback",
                    "Alert sound when resize can't apply"
                ),
                isOn: $model.config.settings.resizeFeedback
            )
        default:
            // The render-parity guard forces every census row of
            // this container into an order list — an unhandled
            // key reaching this arm must fail loud in debug, not
            // vanish.
            let _ = assertionFailure(
                "unrendered Shortcuts census key: \(key.id)"
            )
            EmptyView()
        }
    }

    // A meaning change replaced the old `axes_caption` key
    // (stale since track landed, #128/#183): per
    // docs/translating.md a changed English text gets a NEW
    // key, never a rename — rename-key would carry the stale
    // translations forward as if still valid.
    private var sizeFloatCaption: String {
        L(
            "shortcuts.size_float.layouts_caption",
            "Grow/Shrink only applies in the bsp, stack, "
                + "scrolling, and track layouts; it is a "
                + "no-op in monocle, grid, and floating. "
                + "Width and height resize independently; "
                + "scrolling resizes its slot along the "
                + "scroll axis for both, and in track one "
                + "axis resizes the window's track, the "
                + "other its share within it."
        )
    }
}

/// General app actions (#330): today just the bindable
/// "Show shortcuts panel" hotkey — app chrome, not a workspace
/// action, so it sits in its own low section rather than among
/// Focus / Move / Size. Seeded to ⌃⌥K by default (#602).
struct GeneralShortcutsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    @State private var expanded = false

    var body: some View {
        SettingsDisclosure(
            SettingsCatalog.shortcuts.generalKeys,
            chrome: .card,
            isExpanded: $expanded
        ) {
            ForEach(
                ShortcutsRowOrder.generalKeysMore,
                id: \.id
            ) { key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
            .padding(.top, 8)
        }
    }
}

/// The Layers card: the chip strip that defines the layers, and
/// the rows that switch between them.
///
/// One card because the census places all three families in one
/// container — the strip, its menu-bar icon and the switch rows —
/// and because the switch shortcuts belong beside the definition
/// they act on rather than among the action groups.
///
