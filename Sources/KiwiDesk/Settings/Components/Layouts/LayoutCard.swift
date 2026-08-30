import KiwiDeskCore
import SwiftUI

/// Layout parameters settings card (#678 Phase 3).
struct LayoutCard: View {
    @ObservedObject var model: SettingsModel
    let mode: LayoutMode

    var gates: LayoutDefaultsGates {
        LayoutDefaultsGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.layoutMode(mode),
            symbol: mode.glyph,
            caption: LayoutCardText.blurb(mode)
        ) {
            rows(LayoutDefaultsRowOrder.rows(for: mode))
            appBarCrossReference
        }
    }

    /// Cross-reference link to Bars settings for hosting layouts
    /// (`SidebarCrossReferenceTests`).
    @ViewBuilder private var appBarCrossReference: some View {
        if let host = model.config.settings.appBarHost(for: mode),
            let appBarProse = LayoutCardText.appBarState(
                mode,
                on: host.appBar.enabled
            )
        {
            CrossReferenceRow(
                prose: appBarProse,
                linkTitle: L(
                    "scroll_grid.app_bar_xref_link",
                    "Bars ▸ App Bar"
                ),
                destination: .bars
            )
        }
    }

    private func rows(_ keys: [SettingKey]) -> some View {
        ForEach(keys, id: \.id) { key in
            let reason = gates.inertReason(for: key)
            row(for: key)
                .modifier(
                    GreyOut(
                        active: reason != nil,
                        help: reason.map(
                            LayoutDefaultsGateHelp.sentence
                        ) ?? ""
                    )
                )
        }
    }

    @ViewBuilder func row(for key: SettingKey) -> some View {
        switch key {
        case .layout(let k):
            layoutRow(k)
        case .colours(.animationsOnScrolling):
            animateFocusShiftsRow
        case .colours(.animationsScrollDurationMS):
            scrollDurationRow
        default:
            let _ = assertionFailure(
                "unrendered Layout Defaults key: \(key.id)"
            )
            EmptyView()
        }
    }
}

/// Header blurb and cross-reference text per layout mode.
@MainActor
enum LayoutCardText {
    static func blurb(_ mode: LayoutMode) -> String? {
        switch mode {
        case .bsp:
            return L(
                "layout.bsp.blurb",
                "Every new window splits the one it lands on, so "
                    + "the screen fills without ever overlapping."
            )
        case .stack:
            return L(
                "layout.stack.blurb",
                "One or more master windows beside a stack of "
                    + "the rest, which piles up once it fills."
            )
        case .scrolling:
            return L(
                "layout.scrolling.blurb",
                "One endless row of fixed-width windows; the "
                    + "screen pans along it to the focused one."
            )
        case .grid:
            return L(
                "layout.grid.blurb",
                "Equal cells. A dynamic grid rebalances as "
                    + "windows come and go; a rigid one keeps its "
                    + "shape."
            )
        case .monocle:
            return L(
                "layout.monocle.blurb",
                "Every window fills the screen, one at a time, "
                    + "and focus cycles through them."
            )
        case .track:
            return L(
                "layout.track.blurb",
                "A more advanced layout: several windows can "
                    + "share one track, with a track limit and "
                    + "per-track resize."
            )
        case .floating:
            return nil
        }
    }

    /// App Bar cross-reference prose (`CrossReferenceRowSlotTests`).
    static func appBarState(
        _ mode: LayoutMode,
        on: Bool
    ) -> String? {
        let state =
            on ? L("common.on", "on") : L("common.off", "off")
        switch mode {
        case .monocle:
            return L(
                "monocle.app_bar_xref_state",
                "The monocle App Bar (currently %1$@) is "
                    + "configured in %2$@.",
                state,
                CrossReferenceRow.linkSlot
            )
        case .scrolling:
            return L(
                "scroll_grid.app_bar_xref_state",
                "The scrolling App Bar (currently %1$@) is "
                    + "configured in %2$@.",
                state,
                CrossReferenceRow.linkSlot
            )
        case .bsp, .stack, .grid, .track, .floating:
            // Non-hosting layouts return nil (`CrossReferenceRowSlotTests`).
            return nil
        }
    }
}
