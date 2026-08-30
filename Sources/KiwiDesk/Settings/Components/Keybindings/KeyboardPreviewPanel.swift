import KiwiDeskCore
import SwiftUI

/// Keyboard shortcut allocation preview panel (#678, #812).
///
/// Visualizes bound and available keys across modifier layers
/// via `KeyboardCensus`.
struct KeyboardPreviewPanel: View {
    @ObservedObject var model: SettingsModel
    @State private var scope: KeyboardCensus.Scope = .all

    private var layers: [KeyboardCensus.ModifierLayer] {
        KeyboardCensus.layers(in: model.config.layers)
    }

    private var liveScope: KeyboardCensus.Scope {
        if case .one(let layer) = scope, !layers.contains(layer) {
            return .all
        }
        return scope
    }

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
            SpokenKeyboardBoard(
                type: KeyboardMatrix.PhysicalType.current(),
                claims: claims,
                scope: liveScope,
                conflicted: collisions
            )
            fillLegend.accessibilityHidden(true)
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

    private var collisions: Set<UInt32> {
        KeyboardCensus.collisions(
            in: model.config.layers,
            scope: liveScope
        )
    }

    private var overwritesReserved: Bool {
        !KeyboardCensus.overwrittenReserved(
            claims: claims,
            scope: liveScope
        ).isEmpty
    }

    private var reservedFree: Set<UInt32> {
        KeyboardCensus.reservedUnbound(
            claims: claims,
            scope: liveScope
        )
    }
}
