import KiwiDeskCore
import SwiftUI

/// Advanced Colours' greying (#678 Phase 3). The two bar groups
/// take their block gate from the census container's own
/// `SettingsContainer.gate`, resolved by `BarsGateContext` — the
/// SAME resolver the Bars page uses, never a second copy: the
/// containers deliberately span both areas, which is what carries
/// one gate onto both surfaces, and a re-derived "which bars are
/// shown" predicate is the #520 drift.
///
/// The Borders and Drag groups have no container gate; their rows
/// grey off structural switches that now live on ANOTHER page
/// (Gaps & Borders). That is the one thing this area does
/// differently from every gated editor before it: `GreyOut`'s
/// hover string is documented as sufficient only where the gating
/// control is adjacent, and here it never is. So each group also
/// renders the reason as a live `?` on its section header (#527),
/// and every sentence below names the destination to go to.
/// `@MainActor` unlike `BarsGateContext`, which resolves gates
/// only: this one also picks the SENTENCE, and the localized
/// strings are main-actor state.
@MainActor
struct AdvancedColorsGates {
    let settings: TilingSettings

    /// The bar halves, delegated whole.
    var bars: BarsGateContext { BarsGateContext(settings: settings) }

    // MARK: - Borders

    var borderOn: Bool { settings.borderStyle.enabled }
    var unfocusedOn: Bool { settings.borderStyle.unfocusedEnabled }

    /// The Borders group's header reason, outermost first: a ring
    /// that is off makes its unfocused half moot, so naming both
    /// would send the user to fix the wrong switch.
    var bordersHeaderHelp: String? {
        if !borderOn { return AdvancedColorsHelp.borderOff }
        if !unfocusedOn { return AdvancedColorsHelp.unfocusedOff }
        return nil
    }

    // MARK: - Drag visuals

    func dragVisual(_ ghost: Bool) -> DragVisual {
        ghost ? settings.dragGhost : settings.dragDropZone
    }

    /// One column's header reason. Enabled outranks Border/Fill
    /// for the same reason as the ring above.
    func dragHeaderHelp(ghost: Bool) -> String? {
        let visual = dragVisual(ghost)
        if !visual.enabled { return AdvancedColorsHelp.dragOff }
        if !visual.border { return AdvancedColorsHelp.dragBorderOff }
        if !visual.fill { return AdvancedColorsHelp.dragFillOff }
        return nil
    }

    // MARK: - Space Bar

    /// Nothing to tint when in-chip glyphs are native images AND
    /// no front-app name renders (native images take no tint).
    /// The "name only on horizontal" half mirrors
    /// `SpaceBarOverlay+FrontApp`'s name-visibility rule — keep in
    /// step if that changes.
    var focusedItemInert: Bool {
        let style = settings.spaceBarStyle
        return style.iconSource == .appImage
            && !(style.showFrontApp && style.edge.isHorizontal)
    }
}

/// The why-and-where sentences. Every one names the page that
/// owns the switch, because Advanced Colours is the first area
/// whose gates all live somewhere else.
@MainActor
enum AdvancedColorsHelp {
    static var borderOff: String {
        L(
            "colors.border_off.help",
            // "its two", not "these": the Sticky tint shares
            // this card and is drawn either way, so the plural
            // has to name the ring's own pair.
            "The focus border is off, so its two colors aren't "
                + "drawn. Turn it on in Gaps & Borders."
        )
    }

    static var unfocusedOff: String {
        L(
            "colors.unfocused_off.help",
            "Unfocused windows get no border, so this color "
                + "isn't drawn. Turn it on in Gaps & Borders."
        )
    }

    static var dragOff: String {
        L(
            "colors.drag_off.help",
            "This drag visual is off, so its colors aren't "
                + "drawn. Turn it on in Gaps & Borders."
        )
    }

    static var dragBorderOff: String {
        L(
            "colors.drag_border_off.help",
            "This visual draws no border. Turn Border on in "
                + "Gaps & Borders."
        )
    }

    static var dragFillOff: String {
        L(
            "colors.drag_fill_off.help",
            "This visual draws no fill. Turn Fill on in "
                + "Gaps & Borders."
        )
    }

    /// The Bars page's own gate sentences say "below" and "Turn
    /// on Show Space Bar", both of which point at controls on
    /// that page. From here the user has to be told where.
    static var spaceBarOff: String {
        L(
            "colors.space_bar_off.help",
            "The Space Bar is off, so its colors aren't drawn. "
                + "Turn it on in Bars."
        )
    }

    static var appBarOff: String {
        L(
            "colors.app_bar_off.help",
            "No layout shows an App Bar, so its colors aren't "
                + "drawn. Turn one on in Bars."
        )
    }
}
