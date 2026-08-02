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
    var gates: BarsGateContext {
        BarsGateContext(settings: model.config.settings)
    }
    /// The census container gate, resolved live.
    private var allows: Bool {
        gates.allowsEditing(.appBar)
    }

    var body: some View {
        // The header `?` is the gate's live anchor (#527).
        SettingsSection(
            SettingsCatalog.bars.appBarCard,
            caption: cardCaption,
            help: allows ? nil : BarsGateHelp.noBarShown
        ) {
            AppBarPreviewStrip(style: style.wrappedValue)
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
                        help: BarsGateHelp.noBarShown
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
            chrome: .inline(font: .subheadline),
            isExpanded: $styleExpanded,
            scrollHoisted: true
        ) {
            rows(BarsRowOrder.appBarStyle)
                .padding(.top, 8)
        } accessory: {
            if !styleExpanded {
                Text(styleSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
    /// link (the census's `(action)` row, moved here from the
    /// Space Bar colours block: it copies App Bar → Space Bar,
    /// so it needs the Space Bar on, not the App Bar shown).
    /// The one-shot caveat rides a persistent caption, never
    /// hover alone.
    private var copyAppearanceRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                model.config.settings.spaceBarStyle
                    .copyAppearance(
                        from: model.config.settings.appBarStyle
                    )
            } label: {
                Text(
                    L(
                        "space_bar.copy_appearance",
                        "Copy appearance to Space Bar…"
                    )
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(
                L(
                    "space_bar.copy_appearance.help",
                    "Takes the App Bar's current sizes, style, "
                        + "and colors once; edits afterwards "
                        + "stay independent."
                )
            )
            Text(
                L(
                    "space_bar.copy_appearance.caption",
                    "Copies the App Bar's current sizes, "
                        + "style, and colors — a one-time "
                        + "starting point, not a live link."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .modifier(
            GreyOut(
                active: !model.config.settings
                    .spaceBarStyle.enabled,
                help: BarsGateHelp.spaceBarOff
            )
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
                + "style, copy appearance"
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
