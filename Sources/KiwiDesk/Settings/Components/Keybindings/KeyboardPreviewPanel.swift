import KiwiDeskCore
import SwiftUI

/// Keyboard shortcut allocation preview panel (#678, #812).
///
/// Visualizes bound and available keys across modifier layers
/// via `KeyboardCensus`, for the ONE keybinding layer the strip
/// has selected (#1127) — the panel is a sibling of the section,
/// so the layer arrives on `nav` rather than through the
/// `keybindingLayerName` environment the rows read.
struct KeyboardPreviewPanel: View {
    @ObservedObject var model: SettingsModel
    @State private var scope: KeyboardCensus.Scope = .all
    /// The key under the pointer (#798). Cleared whenever the
    /// board is rebuilt beneath it — a cap replaced under the
    /// pointer never delivers `onHover(false)`, the class of the
    /// `NSCursor` push/pop trap.
    @State var hovered: UInt32?

    /// The drawn layer — the one array every derivation below
    /// folds over (#1127).
    var shown: [KeyLayer] {
        KeyboardCensus.shown(
            model.nav.shortcutsLayerSelection,
            in: model.config.layers
        )
    }

    /// The layer's name, or nil while it is the only one there
    /// is — the census gate's condition, so the answer belongs
    /// to `.switchToLayer`'s `gate:` entry and flips with it: a
    /// gateless placement resolves nil and names a lone layer
    /// (#816, #1127).
    var layerLabel: String? {
        guard ShortcutsGates(config: model.config).layersExist
        else { return nil }
        return shown.first?.name
    }

    private var layers: [KeyboardCensus.ModifierLayer] {
        KeyboardCensus.layers(in: shown)
    }

    var liveScope: KeyboardCensus.Scope {
        if case .one(let layer) = scope, !layers.contains(layer) {
            return .all
        }
        return scope
    }

    var selected: Set<KeyboardCensus.ModifierLayer> {
        KeyboardCensus.inScope(liveScope, among: layers)
    }

    var claims: [UInt32: [KeyboardCensus.ModifierLayer]] {
        KeyboardCensus.claims(
            in: shown,
            selected: selected
        )
    }

    var body: some View {
        board
            // A cap replaced under the pointer never reports
            // leaving, so a scope click or a layer switch would
            // strand the slot on a key the pointer is no longer
            // on — in a scope where it may not even be claimed.
            .onChange(of: liveScope) { _, _ in hovered = nil }
            .onChange(of: model.nav.shortcutsLayerSelection) {
                _,
                _ in
                hovered = nil
            }
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 12) {
            chips
            SpokenKeyboardBoard(
                type: KeyboardMatrix.PhysicalType.current(),
                claims: claims,
                scope: liveScope,
                conflicted: collisions,
                layerLabel: layerLabel,
                onHover: { hovered = $0 },
                conflictDetail: conflictDetail
            )
            statusSlot
            fillLegend.accessibilityHidden(true)
            layoutRow
            // Announced without the layer: the board's one
            // description already named it (#1127). Adjacent to
            // the `Text` on purpose — the guard's needle runs
            // through both, and a modifier that wanders onto a
            // sibling view restores the double announcement
            // while a whole-file scan stays green.
            Text(caption)
                .accessibilityLabel(draftCaption)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
        }
    }

    /// The board names what it draws: once the layer scopes the
    /// picture, a board that changes under a strip click is
    /// legible only if it says which layer it changed to (#1127).
    var caption: String {
        guard let layerLabel else { return draftCaption }
        return L(
            "panel.caption.draft_layer",
            "Shows the \u{201C}%1$@\u{201D} layer in your "
                + "draft, not the saved profile.",
            layerLabel
        )
    }

    private var draftCaption: String {
        L(
            "panel.caption.draft",
            "Shows your draft, not the saved profile."
        )
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
            if !reservedFree.isEmpty {
                lineSwatch(
                    SettingsTheme.keyReserved,
                    dashed: true,
                    L("keyboard.legend.blocked", "macOS owns it")
                )
            }
            if !collisions.isEmpty || overwritesReserved {
                lineSwatch(
                    SettingsTheme.keyConflict,
                    dashed: false,
                    L("keyboard.legend.conflict", "conflict")
                )
            }
        }
    }

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
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            SettingsTheme.planeRing,
                            lineWidth: 1
                        )
                )
                .frame(width: 17, height: 12)
            Text(label)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
        }
    }

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

    private var layoutRow: some View {
        HStack(spacing: 0) {
            ForEach(
                SentenceFrame(
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    SettingsTheme.hairline,
                                    lineWidth: 1
                                )
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

    var collisions: Set<UInt32> {
        KeyboardCensus.collisions(
            in: shown,
            scope: liveScope
        )
    }

    private var overwritesReserved: Bool {
        !KeyboardCensus.overwrittenReserved(
            claims: claims,
            scope: liveScope
        ).isEmpty
    }

    /// The board's own predicate, never a re-derivation: the
    /// rings and this gate read one census set, so the legend
    /// cannot claim a mark the board does not draw.
    private var reservedFree: Set<UInt32> {
        KeyboardCensus.reservedUnbound(
            claims: claims,
            scope: liveScope
        )
    }
}
