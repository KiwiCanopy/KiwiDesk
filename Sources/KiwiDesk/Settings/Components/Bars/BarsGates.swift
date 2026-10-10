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
        // Split only where no screen fuses them (#1948).
        let fused = settings.screenVariants.contains {
            $0.sharedBarEdge != nil
        }
        return fused ? nil : .barsSplit
    }

    /// True while any bar can show — Core's one predicate — so
    /// the shelf has something to place and shape.
    var shelfShows: Bool { settings.shelfShows }

    /// True when the shelf draws a box per item, so no plate is
    /// there for the background size to fit.
    var boxedShelf: Bool {
        settings.kiwishelf.backgroundStyle == .boxed
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
            "The bars, or one bar's screens, sit on different "
                + "edges right now; choosing here puts both bars on "
                + "one edge on every screen."
        )
    }

    /// A bar row's `?` while its screens differ (#1948).
    static var screensDiffer: String {
        L(
            "kiwishelf.edge.screens_differ.help",
            "Your screens put this bar on different edges — "
                + "see \u{201C}%1$@\u{201D} below. Picking an edge "
                + "here puts it there on every screen.",
            L("kiwishelf.edge.per_screen.space_bar", "Per screen")
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
