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
/// and every sentence below names the destination to go to —
/// by INTERPOLATING its live title, never by spelling it out.
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

    /// One column's header reason. `enabled` genuinely outranks
    /// the other two — with the visual off, neither part is
    /// drawn whatever they say. Border and Fill are SIBLINGS,
    /// though, not a second level: with both off, two rows are
    /// dimmed for two different reasons, and the column's one
    /// live `?` is the only place either can be read (help
    /// inside a `GreyOut` is dead, #527). So both sentences are
    /// carried, not the first one found — reporting Border
    /// alone would leave the Fill row dimmed and unexplained.
    func dragHeaderHelp(ghost: Bool) -> String? {
        let visual = dragVisual(ghost)
        if !visual.enabled { return AdvancedColorsHelp.dragOff }
        let reasons = [
            visual.border ? nil : AdvancedColorsHelp.dragBorderOff,
            visual.fill ? nil : AdvancedColorsHelp.dragFillOff,
        ]
        .compactMap { $0 }
        // Whole localized sentences, joined — never assembled
        // from fragments, which a translation could not reorder.
        return reasons.isEmpty
            ? nil : reasons.joined(separator: "\n")
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
///
/// The page name is interpolated positionally from
/// `SettingsDestination.title`, not written into the English.
/// Spelling it out would put the same page name in seven
/// sentences × eleven catalogs with nothing pinning the copies,
/// and this very change renamed one of those pages — the next
/// rename would leave seventy-seven sentences pointing at a
/// destination that no longer exists. Positional specifiers are
/// required here for the ordinary reason too: a translation
/// cannot reorder pieces stitched together in Swift, and several
/// of these locales put the place before the verb.
///
/// Only the TITLE is derived. Which destination owns each gate
/// is still chosen by hand below, and the census already knows
/// it — `gate: .setting(.borders(.borderEnabled))` resolves to a
/// row whose `placement.area` is `.gapsAndBorders`. Deriving it
/// is not available: an area is not a destination (one area
/// spans two of them), so a map would be a fresh twelve-row
/// mirror rather than a derivation. So the obligation is stated
/// instead — **moving a gating control to another destination
/// updates the sentence that points at it, in the same change
/// set** — because nothing here will red when it does not.
@MainActor
enum AdvancedColorsHelp {
    private static var gapsAndBorders: String {
        SettingsDestination.gapsAndBorders.title
    }
    private static var bars: String {
        SettingsDestination.bars.title
    }

    static var borderOff: String {
        L(
            "colors.border_off.help",
            // "its two", not "these": the Sticky tint shares
            // this card and is drawn either way, so the plural
            // has to name the ring's own pair.
            "The focus border is off, so its two colors aren't "
                + "drawn. Turn it on in %1$@.",
            gapsAndBorders
        )
    }

    static var unfocusedOff: String {
        L(
            "colors.unfocused_off.help",
            "Unfocused windows get no border, so this color "
                + "isn't drawn. Turn it on in %1$@.",
            gapsAndBorders
        )
    }

    static var dragOff: String {
        L(
            "colors.drag_off.help",
            "This drag visual is off, so its colors aren't "
                + "drawn. Turn it on in %1$@.",
            gapsAndBorders
        )
    }

    static var dragBorderOff: String {
        L(
            "colors.drag_border_off.help",
            "This visual draws no border. Turn Border on in "
                + "%1$@.",
            gapsAndBorders
        )
    }

    static var dragFillOff: String {
        L(
            "colors.drag_fill_off.help",
            "This visual draws no fill. Turn Fill on in %1$@.",
            gapsAndBorders
        )
    }

    /// The Bars page's own gate sentences say "below" and "Turn
    /// on Show Space Bar", both of which point at controls on
    /// that page. From here the user has to be told where.
    static var spaceBarOff: String {
        L(
            "colors.space_bar_off.help",
            "The Space Bar is off, so its colors aren't drawn. "
                + "Turn it on in %1$@.",
            bars
        )
    }

    static var appBarOff: String {
        L(
            "colors.app_bar_off.help",
            "No layout shows an App Bar, so its colors aren't "
                + "drawn. Turn one on in %1$@.",
            bars
        )
    }
}
