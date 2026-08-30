import KiwiDeskCore
import SwiftUI

/// Settings card for App Bar configuration and layout toggles.
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
        // Section header help provides the gate anchor (#527).
        SettingsSection(
            SettingsCatalog.bars.appBarCard,
            caption: cardCaption,
            help: reason.map(BarsGateHelp.sentence)
        ) {
            // Preview strip renders in BarsPanelPreview (#678).
            rows(BarsRowOrder.appBarAtRest)
            styleDisclosure
            showInBlock
        }
    }

    /// Parallel per-row gates (#520), respecting census exemptions.
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

    /// "Show it in" block for layout-specific toggles.
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

    /// One-shot copy of size and style from Space Bar to App Bar.
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
            // Inline gate reason outside the dimmed subtree
            // (#815, GateReasonPlacement).
            if sourceBarOff, owesInlineGateReason {
                Text(BarsGateHelp.sentence(for: .spaceBarOff))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
            }
        }
    }

    private var sourceBarOff: Bool {
        !model.config.settings.spaceBarStyle.enabled
    }

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
