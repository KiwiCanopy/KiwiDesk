import KiwiDeskCore

/// Resolves Bars area gating states to structured reason codes (#520, #678,
/// `GapsBordersGates`, `GeneralGates`, `LayoutDefaultsGates`,
/// `BarsGateHelp.sentence`). The census is the one copy of container
/// exemptions.
struct BarsGates {
    let settings: TilingSettings

    /// Why a bar block or shown-bar-gated row is inert.
    enum InertReason: Hashable {
        /// No layout shows an App Bar.
        case noBarShown
        /// The Space Bar is switched off.
        case spaceBarOff
        /// The active indicator is Gap — active items are hidden.
        case gapOnly
        /// No bar shows, so the shelf draws nothing to shape.
        case shelfEmpty
        /// Boxed draws a box per item — no plate to size.
        case boxedShelf
    }

    /// Resolves container gate to an inert reason, or nil if active.
    func containerReason(
        for container: SettingsContainer
    ) -> InertReason? {
        switch container {
        case .appBar:
            return anyBarShown ? nil : .noBarShown
        case .spaceBar:
            return settings.spaceBarStyle.enabled
                ? nil : .spaceBarOff
        default:
            return nil
        }
    }

    // MARK: - App Bar row predicates (wiring)

    var shownBars: [LayoutAppBar] {
        settings.appBarHosts.filter(\.enabled)
    }

    var anyBarShown: Bool { settings.anyAppBarCanShow }

    /// True when the Space Bar and an App Bar both show, so the
    /// shelf's order and share apply (#1517).
    var bothBarsShow: Bool { settings.bothBarsCanShow }

    /// Why order and share are inert: whichever of the two bars
    /// is missing, so the sentence names only that one.
    var bothBarsReason: InertReason? {
        if !settings.spaceBarStyle.enabled { return .spaceBarOff }
        return anyBarShown ? nil : .noBarShown
    }

    /// True while any bar can show — Core's one predicate — so
    /// the shelf has something to place and shape.
    var shelfShows: Bool { settings.shelfShows }

    /// True when the shelf draws a box per item, so no plate is
    /// there for the background size to fit.
    var boxedShelf: Bool {
        settings.kiwishelf.backgroundStyle == .boxed
    }

    /// True when EVERY shown bar renders on a vertical edge.
    var everyShownBarVertical: Bool {
        anyBarShown && !settings.kiwishelf.edge.isHorizontal
    }

    /// True when no shown bar renders an icon at all.
    var everyShownBarTitleOnly: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                settings.appBarLook(for: $0).renderedContent == .title
            }
    }

    /// True when active indicator hides active items outright
    /// (`AppBarOverlay`, `AppBarItemView`).
    var gapOnly: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                settings.appBarLook(for: $0).activeIndicator == .gap
            }
    }
}

/// Explanatory hover/help text for bar gate reasons (#678).
@MainActor
enum BarsGateHelp {
    static func sentence(for reason: BarsGates.InertReason) -> String {
        switch reason {
        case .noBarShown:
            // Points to the block holding the switches (#705, #818).
            return L(
                "app_bar.no_layout.shelf_help",
                "No layout shows an App Bar — turn one on under "
                    + "“%1$@” in %2$@.",
                L("kiwishelf.show.label", "Show"),
                L("bars.switch.kiwishelf", "KiwiShelf")
            )
        case .spaceBarOff:
            return L(
                "space_bar.disabled.shelf_help",
                "Turn on the Space Bar under “%1$@” in %2$@ to edit "
                    + "these settings.",
                L("kiwishelf.show.label", "Show"),
                L("bars.switch.kiwishelf", "KiwiShelf")
            )
        case .shelfEmpty:
            return L(
                "kiwishelf.empty.help",
                "Turn on a bar under \u{201C}%1$@\u{201D} to edit "
                    + "these settings.",
                L("kiwishelf.show.label", "Show")
            )
        case .boxedShelf:
            return L(
                "kiwishelf.background_fit.boxed_only",
                "\u{201C}%1$@\u{201D} draws a box per item, "
                    + "not a shared plate, so there is "
                    + "nothing to size.",
                L("app_bar.background_style.boxed", "Boxed")
            )
        case .gapOnly:
            // Interpolated from picker entry (#818).
            return L(
                "app_bar.color.gap_only",
                "The \u{201C}%1$@\u{201D} indicator hides the "
                    + "active item instead of marking it, so "
                    + "these colors aren't drawn.",
                L("app_bar.active_indicator.gap", "Gap")
            )
        }
    }
}
