import KiwiDeskCore
import SwiftUI

/// "KEYBOARD · WHAT'S TAKEN" — the Shortcuts area's panel
/// content (#678 turn 5a). One resolved keyboard, drawn from the
/// draft, answering which physical keys the user's bindings have
/// already claimed and under which modifier combinations.
///
/// The chip row is the state everything else derives from: the
/// board and the count sentence both read the same scope through
/// `KeyboardCensus`, so the sentence cannot disagree with the
/// picture above it.
struct KeyboardPreviewPanel: View {
    @ObservedObject var model: SettingsModel

    /// Which modifier combinations are showing. Seeded to all of
    /// them on first render and then narrowed by the user —
    /// starting empty would open on a board that answers nothing.
    /// Which combination the board is showing, or all of them.
    /// Opens on `.all` — the only answer that stays true however
    /// many combinations the draft has, since a board narrowed to
    /// a subset reads as the total under this panel's heading.
    @State private var scope: KeyboardCensus.Scope = .all

    /// Every combination the draft uses. Each gets a chip.
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
                conflicted: collisions
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
        FlowLayout(spacing: 6) {
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
        FlowLayout(spacing: 12) {
            swatch(
                SettingsTheme.accent,
                L("keyboard.legend.bound", "bound")
            )
            swatch(
                SettingsTheme.keyFree,
                L("keyboard.legend.free", "free")
            )
            if liveScope != .all {
                // `.all` never yields `.cantBind` (macOS reserves
                // a key UNDER a modifier), so naming the mark
                // there would point at one the board cannot draw.
                lineSwatch(
                    SettingsTheme.keyReserved,
                    dashed: true,
                    L("keyboard.legend.blocked", "macOS owns it")
                )
            }
            lineSwatch(
                SettingsTheme.keyConflict,
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

    /// A label rather than a sentence ("Keys taken: 12", not "12
    /// keys taken."), because one catalog string has no plural
    /// forms: every inflected locale would have to pick a single
    /// grammatical number and be wrong at the others — "1 Tasten
    /// belegt", "0 touches attribuées". Putting the count last
    /// leaves nothing to agree with it. No terminal period for
    /// the same reason it is not a sentence, and because a period
    /// straight after a digit reads as a thousands separator in
    /// six of the shipped locales.
    private var tallySentence: some View {
        let taken = KeyboardCensus.takenKeyCount(claims: claims)
        return Text(
            L(
                "keyboard.tally",
                "Keys taken: %1$d",
                taken
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
    ///
    /// ONE localized frame with the value at `%1$@`, rendered
    /// through `SentenceFrame` — not `Text` · chip · `Text`.
    /// Sibling views stitched around a value is the same defect
    /// as `+`-concatenating fragments: the chip could only ever
    /// land in the middle, and no catalog could move it (gui.md
    /// ▸ Strings, the `CrossReferenceRow` case).
    private var layoutRow: some View {
        // Spacing 0: the frame's own literals carry it. A
        // per-segment gap merely double-spaces English and is
        // wrong outright wherever the literal after a slot opens
        // with a particle that must hug the noun before it.
        HStack(spacing: 0) {
            ForEach(
                SentenceFrame(
                    // "Keyboard layout", never bare "Layout":
                    // that word is this app's own tiling noun
                    // (`destination.layout` is "Layout
                    // Defaults"), and this sentence sits inside
                    // Settings where both senses are one search
                    // away from each other.
                    L(
                        "keyboard.layout.sentence",
                        "Keyboard layout %1$@ from macOS"
                    )
                ).segments
            ) { segment in
                switch segment.slot {
                case .text(let words):
                    Text(words)
                        .foregroundStyle(SettingsTheme.ink3)
                case .argument:
                    Text(layoutName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SettingsTheme.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(SettingsTheme.card)
                        )
                }
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(SettingsTheme.sunken)
        )
    }

    private var layoutName: String {
        L(
            "keyboard.layout.value",
            "%1$@ · %2$@",
            KeyboardMatrix.PhysicalType.current().label,
            KeyboardInputSource.localizedName()
                ?? L("keyboard.layout.unknown", "Unknown")
        )
    }

    // MARK: - Derived

    /// The red ring's keys: two bindings in one layer claiming
    /// the same combo. A clash with a macOS shortcut is NOT one
    /// of these — the dashed ring says that, and saying it in red
    /// would blame the user's own bindings for it.
    private var collisions: Set<UInt32> {
        KeyboardCensus.collisions(
            in: model.config.layers,
            scope: liveScope
        )
    }

}
