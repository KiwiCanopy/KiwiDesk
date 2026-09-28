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
        /// No shown bar draws an app icon: the Space Bar is off and
        /// every shown App Bar is title-only.
        case noAppIcon
        /// No bar shows, so the shelf draws nothing to shape.
        case shelfEmpty
        /// Boxed draws a box per item — no plate to size.
        case boxedShelf
        /// The bars sit on different edges, so nothing shares one
        /// (#1731).
        case barsSplit
        /// The shelf's font family is not installed, so System
        /// draws and the family has no weights to offer (#1681).
        case fontMissing(family: String)
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
        case .kiwishelf:
            return shelfShows ? nil : .shelfEmpty
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
    /// is missing, so the sentence names only that one, else the
    /// two sitting on different edges (#1731). Nil while no bar
    /// shows: the card's block grey answers then.
    var bothBarsReason: InertReason? {
        guard settings.shelfShows else { return nil }
        if !settings.spaceBarStyle.enabled { return .spaceBarOff }
        guard anyBarShown else { return .noBarShown }
        return settings.sharedBarEdge == nil ? .barsSplit : nil
    }

    /// True while any bar can show — Core's one predicate — so
    /// the shelf has something to place and shape.
    var shelfShows: Bool { settings.shelfShows }

    /// True when the shelf draws a box per item, so no plate is
    /// there for the background size to fit.
    var boxedShelf: Bool {
        settings.kiwishelf.backgroundStyle == .boxed
    }

    /// True when an App Bar shows and its edge is vertical, so
    /// it draws icons only (#1731: the App Bar's own edge).
    var appBarVertical: Bool {
        anyBarShown && !settings.appBarStyle.edge.isHorizontal
    }

    /// True when no shown bar renders an icon at all.
    var everyShownBarTitleOnly: Bool {
        anyBarShown
            && shownBars.allSatisfy {
                settings.appBarLook(for: $0).renderedContent == .title
            }
    }

    /// True when a bar shows but none draws an app icon, so the
    /// shelf's glyph style has nothing to style.
    var noBarDrawsIcon: Bool {
        !settings.spaceBarStyle.enabled && everyShownBarTitleOnly
    }

    /// Why the font weight is inert: the family is not installed.
    @MainActor var fontWeightReason: InertReason? {
        let family = settings.kiwishelf.fontFamily
        return BarFont.isInstalled(family)
            ? nil : .fontMissing(family: family)
    }
}

/// Explanatory hover/help text for bar gate reasons (#678).
@MainActor
enum BarsGateHelp {
    /// The Position master's acknowledgement while the bars sit
    /// on different edges (#1731) — not an `InertReason`: the
    /// master stays live, and a pick re-fuses them.
    static var edgesDiffer: String {
        L(
            "kiwishelf.edge.differ.help",
            "The bars sit on different edges right now; choosing "
                + "here puts both on one."
        )
    }

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
        case .noAppIcon:
            // Interpolated from picker entry (#818).
            return L(
                "kiwishelf.icon_source.no_icon",
                "The Space Bar is off and the App Bar's "
                    + "\u{201C}%1$@\u{201D} is \u{201C}%2$@\u{201D}, "
                    + "so no app glyph is drawn.",
                L("app_bar.content.label", "Content"),
                L("app_bar.content.title", "Title")
            )
        case .barsSplit:
            return L(
                "kiwishelf.bars_split.help",
                "Applies while both bars share an edge."
            )
        case .fontMissing(let family):
            return L(
                "kiwishelf.font_weight.missing_family",
                "“%1$@” isn't installed, so there is no weight "
                    + "of its own to choose.",
                family
            )
        }
    }
}
