import KiwiDeskCore
import SwiftUI

/// The App Bar card (turn 7a): Position, Thickness and the
/// grouping toggle at rest, one Style disclosure, then the
/// "Show it in" block — the two per-layout switches that
/// replaced the per-layout override sub-editors
/// (GUI_REMOVED_2026-08; styling stays fully available in Lua).
/// There is no global on/off row because the bar doesn't have
/// one — visibility is per layout.
///
/// Census-rendered like `SpaceBarCard`: `BarsRowOrder` gives
/// the order, the `.appBar` container's gate greys the card
/// wholesale, and `exemptFromContainerGate` names the rows that
/// stay live — the two Show-it-in switches (which own the
/// gate), the symbol-style picker (it also feeds the ⌃⌥K
/// panel's Apps band) and the copy-appearance action (gated on
/// the Space Bar instead).
struct AppBarCard: View {
    @ObservedObject var model: SettingsModel
    @State private var styleExpanded = false

    var style: Binding<AppBarStyle> {
        $model.config.settings.appBarStyle
    }
    var gates: BarsGates {
        BarsGates(settings: model.config.settings)
    }
    /// The census container gate, resolved live to a reason.
    private var reason: BarsGates.InertReason? {
        gates.containerReason(for: .appBar)
    }
    private var allows: Bool { reason == nil }

    var body: some View {
        // The header `?` is the gate's live anchor (#527).
        SettingsSection(
            SettingsCatalog.bars.appBarCard,
            caption: cardCaption,
            help: reason.map(BarsGateHelp.sentence)
        ) {
            // The strip moved to the detail PANEL
            // (`BarsPanelPreview`, #678 redesign spec); the palette
            // mirror keeps its own mount.
            rows(BarsRowOrder.appBarAtRest)
            styleDisclosure
            showInBlock
        }
    }

    /// Parallel per-row gates, never nested (#520): each row
    /// carries the container gate unless the census exempts it.
    private func rows(_ keys: [SettingKey]) -> some View {
        ForEach(keys, id: \.id) { key in
            row(for: key)
                .modifier(
                    GreyOut(
                        active: !allows
                            && !key.placement
                                .exemptFromContainerGate,
                        help: BarsGateHelp.sentence(for: .noBarShown)
                    )
                )
        }
    }

    @ViewBuilder private func row(for key: SettingKey) -> some View {
        switch key {
        case .appBar(let k):
            appBarRow(k)
        case .spaceBar(.copyAppearance):
            copyAppearanceRow
        case .layoutAppBar(let k):
            showInRow(k)
        default:
            // The render-parity guard forces every census row
            // of this container into the order lists — an
            // unhandled key reaching this arm must fail loud
            // in debug, not vanish.
            let _ = assertionFailure(
                "unrendered Bars census key: \(key.id)"
            )
            EmptyView()
        }
    }

    private var styleDisclosure: some View {
        SettingsDisclosure(
            SettingsCatalog.bars.appBarStyle,
            isExpanded: $styleExpanded,
            scrollHoisted: true,
            summary: styleSummary
        ) {
            rows(BarsRowOrder.appBarStyle)
                .padding(.top, 8)
        }
    }

    /// "Show it in", after the Style disclosure: the only
    /// layouts that can carry an App Bar. Live while the card
    /// greys — these own the gate, or the lockout would be
    /// permanent.
    @ViewBuilder private var showInBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("bars.show_in.title", "Show it in"))
                .font(.subheadline.weight(.semibold))
            Text(showInCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        rows(BarsRowOrder.appBarShowIn)
    }

    /// One switch per bar-hosting layout, search-anchored so
    /// "Monocle" finds the row that decides its bar.
    @ViewBuilder private func showInRow(
        _ key: LayoutAppBarKey
    ) -> some View {
        switch key {
        case .monocleAppBarEnabled:
            Toggle(
                L("layout.monocle.name", "Monocle"),
                isOn: $model.config.settings.monocle.appBar.enabled
            )
            .searchAnchored(SettingsCatalog.bars.monocleShowIn)
        case .scrollingAppBarEnabled:
            Toggle(
                L("layout.scrolling.name", "Scrolling"),
                isOn: $model.config.settings.scrolling.appBar
                    .enabled
            )
            .searchAnchored(SettingsCatalog.bars.scrollingShowIn)
        default:
            let _ = assertionFailure(
                "unrendered Show-it-in key: \(key.rawValue)"
            )
            EmptyView()
        }
    }

    /// One-shot copy, then fully independent — never a live
    /// link. Owner flipped the DIRECTION (2026-08-10): a
    /// button on THIS card fills in THIS bar from the Space
    /// Bar the user already configured — pushing outward
    /// surprised on sight — and it rides at rest, always
    /// visible (the adjust-gaps precedent). It
    /// needs the SOURCE (Space Bar) on, not the App Bar
    /// shown. Sizes and style ONLY — colours are the Advanced
    /// Colours area's concern (owner ruling 2026-08-02; a
    /// colours-copy, if it ships, lives there). The one-shot
    /// caveat rides a persistent caption, never hover alone.
    private var copyAppearanceRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    model.config.settings.appBarStyle
                        .copyAppearance(
                            from: model.config.settings
                                .spaceBarStyle
                        )
                } label: {
                    Text(
                        L(
                            "app_bar.copy_appearance",
                            "Copy sizes and style from Space Bar…"
                        )
                    )
                }
                .settingsActionButton()
                .controlSize(.small)
                .help(copyAppearanceHelp)
                Text(
                    L(
                        "app_bar.copy_appearance.caption",
                        "Copies the Space Bar's current sizes "
                            + "and style — not its colors — as a "
                            + "one-time starting point, never a "
                            + "live link."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .modifier(
                GreyOut(
                    active: sourceBarOff,
                    help: BarsGateHelp.sentence(for: .spaceBarOff)
                )
            )
            // The gate's reason, INLINE and OUTSIDE the dimmed
            // subtree (#815): a dim says an answer exists, and
            // this row's answer is on another card of this same
            // page, so nothing beside the button connects the
            // two. The caption above says what the verb does,
            // never why it is dead — which is exactly the
            // distinction that let this ship with the reason in
            // a tooltip.
            //
            // The census is ASKED rather than quoted: a comment
            // claiming `GateReasonPlacement` puts this row in
            // that class, over an `if` that re-derives it, is
            // the dead-resolver shape gui.md names — the type
            // would then answer for nobody and a row whose
            // adjacency changed would keep drawing this
            // (architect review, 2026-08-12).
            if sourceBarOff, owesInlineGateReason {
                Text(BarsGateHelp.sentence(for: .spaceBarOff))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
            }
        }
    }

    /// The source bar being off is what kills the copy — read
    /// once, so the dim and the sentence cannot disagree.
    private var sourceBarOff: Bool {
        !model.config.settings.spaceBarStyle.enabled
    }

    /// Whether this row's reason travels inline, per the census.
    /// Nothing here decides it: give the copy action a gating
    /// control on this card and the derivation answers
    /// `.adjacent`, and this sentence retires itself.
    private var owesInlineGateReason: Bool {
        GateReasonPlacement.owesInlineReason(
            .spaceBar(.copyAppearance)
        )
    }

    private var copyAppearanceHelp: String {
        L(
            "app_bar.copy_appearance.help",
            "Takes the Space Bar's current sizes and "
                + "style once — thickness, background, "
                + "indicator and the rest. Colors are "
                + "not copied; edits afterwards stay "
                + "independent."
        )
    }

    private var cardCaption: String {
        L(
            "bars.app_bar.caption",
            "The windows in the current Space, shown per "
                + "layout."
        )
    }

    private var styleSummary: String {
        L(
            "bars.style.app_bar.summary",
            "Background, content, indicator, sizes, symbol "
                + "style"
        )
    }

    private var showInCaption: String {
        L(
            "bars.show_in.caption",
            "Only these layouts can carry an App Bar. The "
                + "other layouts keep every window visible, so "
                + "they show none; the Space Bar shows in every "
                + "layout."
        )
    }
}
