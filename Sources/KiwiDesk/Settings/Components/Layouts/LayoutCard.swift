import KiwiDeskCore
import SwiftUI

/// One layout's parameter card, rendered from the census (#678
/// Phase 3, turn 10): `LayoutDefaultsRowOrder` gives the order,
/// `SettingPlacement` the tier and gate, and
/// `LayoutDefaultsGates` resolves every gate the rows declare.
///
/// Only the selected layout's card is ever mounted, which is the
/// point of the strip above it: the area's thirty-six rows never
/// appear at once, and the most anyone sees is eight.
///
/// No block gate and no disclosure — a layout's card is never
/// off as a unit, because the card *is* the layout the reader
/// picked, and a "show more" inside it would be a second door
/// behind the one they just opened.
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

    /// Monocle and Scrolling are the only layouts that host an
    /// App Bar, and its enable toggle plus all its styling are
    /// owned by the Bars page. The row is chrome, not a census
    /// row — it sets nothing — but it carries the bar's live
    /// On/Off state so it isn't a dead pointer, which is the
    /// design consult's ruling from when this row was born.
    ///
    /// Layout Defaults is a Nerd-mode area and Bars is a Simple
    /// one, so the destination always exists in the mode the
    /// reader is already in (item 14).
    @ViewBuilder private var appBarCrossReference: some View {
        if let host = model.config.settings.appBarHost(for: mode) {
            CrossReferenceRow(
                prose: LayoutCardText.appBarState(
                    mode,
                    on: host.appBar.enabled
                ),
                linkTitle: L(
                    "scroll_grid.app_bar_xref_link",
                    "App Bar"
                ),
                destination: .bars
            )
        }
    }

    /// Each row carries the grey its census gate resolves to —
    /// asked of the resolver, never re-derived here, so the
    /// declared owner and the on-screen grey cannot drift.
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
        case .colours(.animationsScrollSpeedMS):
            scrollSpeedRow
        default:
            // The render-parity guard forces every census row of
            // these containers into the order lists, so a
            // cross-family key placed in one reaches this arm —
            // it must fail loud in debug rather than vanish.
            let _ = assertionFailure(
                "unrendered Layout Defaults key: \(key.id)"
            )
            EmptyView()
        }
    }
}

/// The per-layout header caption — one sentence saying what the
/// layout does, so the card answers "what am I tuning" without
/// the reader having to decode its rows. Split from the view so
/// the strings sit together rather than inside a `switch` in a
/// `body`.
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
            // Floating has no card — nothing to tune, so it
            // never reaches the strip.
            return nil
        }
    }

    /// The App Bar cross-reference's prose, with the bar's live
    /// state AND the destination link read into the sentence —
    /// the link as `CrossReferenceRow.linkSlot`, so a
    /// translation may put the pane's name wherever its word
    /// order wants it rather than dangling off the end.
    /// One key per layout, because
    /// the layout's name is inside it and a language that
    /// inflects around that name cannot be handed a bare noun.
    /// Exhaustive rather than defaulted, so a third hosting
    /// layout fails to COMPILE — which is the discipline this
    /// area states everywhere else, and a `default:` here would
    /// quietly give that layout Scrolling's sentence.
    static func appBarState(
        _ mode: LayoutMode,
        on: Bool
    ) -> String {
        let state =
            on ? L("common.on", "on") : L("common.off", "off")
        switch mode {
        case .monocle:
            return L(
                "monocle.app_bar_xref_state",
                "The monocle app bar (currently %1$@) is "
                    + "configured in %2$@.",
                state,
                CrossReferenceRow.linkSlot
            )
        case .scrolling:
            return L(
                "scroll_grid.app_bar_xref_state",
                "The scrolling app bar (currently %1$@) is "
                    + "configured in %2$@.",
                state,
                CrossReferenceRow.linkSlot
            )
        case .bsp, .stack, .grid, .track, .floating:
            // Unreachable while Core's `appBarHost(for:)` — the
            // one copy of who may show a bar — grants no host to
            // these. That is the axis the exhaustive switch does
            // NOT defend: granting Grid a host compiles, because
            // Grid is already listed, and would ship an empty
            // sentence beside a live link in every locale. Loud
            // in debug, silent in release, like every other
            // unreachable arm in this area.
            assertionFailure(
                "app bar host with no sentence: \(mode)"
            )
            return ""
        }
    }
}
