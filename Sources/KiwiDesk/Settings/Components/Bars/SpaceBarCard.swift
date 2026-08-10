import KiwiDeskCore
import SwiftUI

/// The Space Bar card (turn 7a): the at-rest rows — does the
/// bar exist, where, how thick, the two content toggles — with
/// everything else behind one Style disclosure. Rendered from
/// the census: `BarsRowOrder` gives the order,
/// `SettingPlacement` the tier and gate, and the card's block
/// gate is the `.spaceBar` container's own
/// (`SettingsContainer.gate`), with
/// `exemptFromContainerGate` naming the rows that stay live —
/// the Show toggle, which owns the gate.
struct SpaceBarCard: View {
    @ObservedObject var model: SettingsModel
    @State private var styleExpanded = false

    var style: Binding<SpaceBarStyle> {
        $model.config.settings.spaceBarStyle
    }
    private var gates: BarsGates {
        BarsGates(settings: model.config.settings)
    }
    /// The census container gate, resolved live to a reason.
    private var reason: BarsGates.InertReason? {
        gates.containerReason(for: .spaceBar)
    }
    private var allows: Bool { reason == nil }

    var body: some View {
        // The header `?` is the gate's live anchor (#527): every
        // help affordance inside the greyed rows is dead, so the
        // why-off explanation must live outside them.
        SettingsSection(
            SettingsCatalog.bars.spaceBarCard,
            caption: cardCaption,
            help: reason.map(BarsGateHelp.sentence)
        ) {
            // The strip moved to the detail PANEL
            // (`BarsPanelPreview`, #678 redesign spec) — the column
            // beside these rows is where the draft is watched
            // now; the palette mirror keeps its own mount.
            rows(BarsRowOrder.spaceBarAtRest)
            styleDisclosure
        }
    }

    /// Each row individually carries the container gate unless
    /// the census exempts it — parallel `GreyOut`s, never
    /// nested, so nothing compounds to 0.25.
    private func rows(_ keys: [SettingKey]) -> some View {
        ForEach(keys, id: \.id) { key in
            row(for: key)
                .modifier(
                    GreyOut(
                        active: !allows
                            && !key.placement
                                .exemptFromContainerGate,
                        help: BarsGateHelp.sentence(for: .spaceBarOff)
                    )
                )
        }
    }

    @ViewBuilder private func row(for key: SettingKey) -> some View {
        switch key {
        case .spaceBar(let k):
            spaceBarRow(k)
        default:
            // The render-parity guard forces every census row
            // of this container into the order lists — a
            // cross-family key placed here (the shape
            // `.spaceBar(.copyAppearance)` in `.appBar`
            // proves possible) reaches this arm, so it must
            // fail loud in debug, not vanish.
            let _ = assertionFailure(
                "unrendered Bars census key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// The Style disclosure (the card's one "Show more" row,
    /// turn 7a). Collapsed it names what it hides; the block
    /// gate rides the rows inside, never the disclosure — a
    /// disabled disclosure refuses to toggle (#527).
    private var styleDisclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.bars.spaceBarStyle,
            chrome: .inline(font: .subheadline),
            isExpanded: $styleExpanded,
            scrollHoisted: true
        ) {
            rows(BarsRowOrder.spaceBarStyle)
                .padding(.top, 8)
        } accessory: {
            if !styleExpanded {
                Text(styleSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cardCaption: String {
        L(
            "bars.space_bar.caption",
            "One item per Space, always on screen — one bar "
                + "per display, every layout."
        )
    }

    private var styleSummary: String {
        L(
            "bars.style.space_bar.summary",
            "Background, alignment, indicator, sizes, glyph "
                + "cap, spring delay"
        )
    }
}
