import KiwiDeskCore
import SwiftUI

/// "KEYBOARD · WHAT'S TAKEN" — the Shortcuts area's panel
/// content (#678 turn 5a). One resolved keyboard, drawn from the
/// draft, answering which physical keys the user's bindings have
/// already claimed and under which modifier combinations.
///
/// The chip row is the state everything else derives from: the
/// board stripes, the stripe legend and the count sentence all
/// read the same selection, through `KeyboardCensus`, so the
/// sentence cannot disagree with the picture above it.
struct KeyboardPreviewPanel: View {
    @ObservedObject var model: SettingsModel

    /// Which modifier combinations are showing. Seeded to all of
    /// them on first render and then narrowed by the user —
    /// starting empty would open on a board that answers nothing.
    /// Which combination the board is showing, or all of them.
    /// Opens on `.all` — the only answer that stays true however
    /// many combinations the draft has.
    @State private var scope: KeyboardCensus.Scope = .all

    /// Every combination the draft uses. All of them get a chip;
    /// only `KeyboardStripePalette.capacity` of them can stripe
    /// at once, because that is how many colours hold the
    /// colour-vision separation floor against each other and
    /// against the key they sit on.
    private var layers: [KeyboardCensus.ModifierLayer] {
        KeyboardCensus.layers(in: model.config.layers)
    }

    /// The scope, dropped back to `.all` if the draft no longer
    /// has the combination it names — unbinding the last ⌘
    /// shortcut must not leave the board showing a ⌘ that is not
    /// there.
    private var liveScope: KeyboardCensus.Scope {
        if case .one(let layer) = scope, !layers.contains(layer) {
            return .all
        }
        return scope
    }

    /// The selection, minus any layer the draft no longer has —
    /// unbinding the last ⌘ shortcut must not leave a ⌘ chip
    /// selected and counted.
    private var selected: Set<KeyboardCensus.ModifierLayer> {
        KeyboardCensus.inScope(liveScope, among: layers)
    }

    private var claims: [UInt32: [KeyboardCensus.ModifierLayer]] {
        KeyboardCensus.claims(
            in: model.config.layers,
            selected: selected
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chips
            KeyboardBoard(
                type: KeyboardMatrix.PhysicalType.current(),
                claims: claims,
                scope: liveScope,
                conflicted: conflictedCodes
            )
            fillLegend
            tallySentence
            layoutRow
            Text(
                L(
                    "panel.caption.draft",
                    "Shows your draft, not the saved profile."
                )
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
        }
    }

    // MARK: - Chips

    private var chips: some View {
        FlowRow(spacing: 6) {
            ScopeChip(
                label: L("keyboard.scope.all", "All"),
                isOn: liveScope == .all
            ) {
                scope = .all
            }
            ForEach(layers, id: \.self) { layer in
                ScopeChip(
                    label: KeyboardKeyLabel.chipLabel(for: layer),
                    isOn: liveScope == .one(layer)
                ) {
                    scope = .one(layer)
                }
            }
        }
    }

    // MARK: - Legends

    /// Each entry is drawn the way the board draws the thing it
    /// names: a fill for a fill, a line for a ring. A square of
    /// solid colour standing for a 1.5 pt dashed border is the
    /// caption rule's failure in miniature — a legend may not
    /// point at a mark the frame does not draw.
    private var fillLegend: some View {
        FlowRow(spacing: 12) {
            swatch(
                SettingsTheme.accent,
                L("keyboard.legend.bound", "bound")
            )
            swatch(
                SettingsTheme.keyFree,
                L("keyboard.legend.free", "free")
            )
            lineSwatch(
                SettingsTheme.keyReserved,
                dashed: true,
                L("keyboard.legend.blocked", "macOS owns it")
            )
            lineSwatch(
                SettingsTheme.danger,
                dashed: false,
                L("keyboard.legend.conflict", "conflict")
            )
        }
    }

    /// A fill swatch, delimited by a hairline rather than set on
    /// a plate of its own. The plate was there because a pale
    /// key fill vanished on the light panel; the fills are the
    /// app's accent and a dark grey now, and a hairline states
    /// the swatch's edge on either appearance without reading as
    /// a frame around one item.
    private func swatch(_ fill: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            SettingsTheme.hairline,
                            lineWidth: 1
                        )
                )
                .frame(width: 17, height: 12)
            Text(label)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
        }
    }

    /// A ring, drawn as the KEY-SHAPED outline it is on the
    /// board — dashed for reserved, solid for a conflict. A
    /// capsule read as a pill rather than as a key edge.
    private func lineSwatch(
        _ stroke: Color,
        dashed: Bool,
        _ label: String
    ) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    stroke,
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: dashed ? [3, 2] : []
                    )
                )
                .frame(width: 17, height: 12)
            Text(label)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
        }
    }

    // MARK: - Sentence and layout row

    private var tallySentence: some View {
        let tally = KeyboardCensus.tally(claims: claims)
        return Text(
            L(
                "keyboard.tally",
                "%1$d keys taken.",
                tally.keys
            )
        )
        .font(.caption)
        .foregroundStyle(SettingsTheme.ink2)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// States what was RESOLVED, never offers a choice — the app
    /// binds by physical position and stores no layout, so this
    /// is a reading of the machine, which is what "from macOS"
    /// tells the user.
    private var layoutRow: some View {
        HStack(spacing: 6) {
            Text(L("keyboard.layout", "Layout"))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
            Text(
                L(
                    "keyboard.layout.value",
                    "%1$@ · %2$@",
                    KeyboardMatrix.PhysicalType.current().label,
                    KeyboardInputSource.localizedName()
                        ?? L("keyboard.layout.unknown", "Unknown")
                )
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(SettingsTheme.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(SettingsTheme.card)
            )
            Text(L("keyboard.layout.source", "from macOS"))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(SettingsTheme.sunken)
        )
    }

    // MARK: - Derived

    /// Conflicts are per layer and never across them, so this is
    /// the set of codes the existing detector already reports —
    /// the panel marks them, it does not re-decide them.
    private var conflictedCodes: Set<UInt32> {
        let names = Set(
            KeybindingConflicts
                .conflicts(in: model.config.layers)
                .map(\.name)
        )
        guard !names.isEmpty else { return [] }
        return Set(
            model.config.layers
                .flatMap(\.bindings)
                .filter { names.contains($0.label) }
                .compactMap { KeyCombo.parse($0.combo)?.keyCode }
        )
    }

}
