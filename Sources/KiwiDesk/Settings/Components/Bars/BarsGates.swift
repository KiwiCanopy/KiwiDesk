import KiwiDeskCore

/// Resolves Bars area gating states to structured reason codes (#520, #678,
/// `GapsBordersGates`, `GeneralGates`, `LayoutDefaultsGates`,
/// `BarsGateHelp.sentence`). The census is the one copy of container
/// exemptions.
struct BarsGates {
    let settings: TilingSettings
    /// Whether the GUI owns the config — the app-wide rows' gate.
    var guiManaged = true

    /// Why a bar block or shown-bar-gated row is inert.
    enum InertReason: Hashable {
        /// Boxed draws a box per item — no plate to size.
        case boxedShelf
        /// The bars sit on different edges, so nothing shares one
        /// (#1731).
        case barsSplit
        /// The shelf's font family is not installed, so System
        /// draws and the family has no weights to offer (#1681).
        case fontMissing(family: String)
        /// `init.lua` owns the config, so an app-wide row it does
        /// not store is not the GUI's to write (#1741).
        case appWideLuaOwned
    }

    /// Runtime-gated keys this resolver answers directly. Data, so
    /// the guard asserts the split against the census — a new
    /// runtime-gated bars row landing in neither set reds. A bars
    /// row's `.setting` gate is wiring's, as gui.md rules.
    static let resolved: Set<SettingKey> = [.spaceBar(.spaceCue)]

    /// Runtime-gated bars keys answered elsewhere.
    static let resolvedElsewhere: Set<SettingKey> = []

    /// Resolves a row's declared runtime gate (#2228).
    func inertReason(for key: SettingKey) -> InertReason? {
        switch key {
        case .spaceBar(.spaceCue):
            return guiManaged ? nil : .appWideLuaOwned
        default:
            assertionFailure("BarsGates does not own \(key.id)")
            return nil
        }
    }

    // MARK: - Shelf row predicates (wiring)

    /// Why order and share are inert: the two bars sit on
    /// different edges, so nothing shares one (#1731). A hidden
    /// bar's shortcut still lays it beside the other, so order and
    /// share stay live whatever the visibilities (#761).
    var bothBarsReason: InertReason? {
        // Split only where no screen fuses them (#1948).
        let fused = settings.screenVariants.contains {
            $0.sharedBarEdge != nil
        }
        return fused ? nil : .barsSplit
    }

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

    /// The Show master's acknowledgement while the bars show
    /// differently (#761): the master stays live, and a pick sets
    /// every bar.
    static var visibilityDiffers: String {
        L(
            "kiwishelf.show.differ.help",
            "Your bars show differently right now; choosing here "
                + "sets every bar."
        )
    }

    /// A bar row's `?` while its screens differ (#1948), naming
    /// that bar's own Per screen drawer.
    static func screensDiffer(appBar: Bool) -> String {
        L(
            "kiwishelf.edge.screens_differ.help",
            "Your screens put this bar on different edges — "
                + "see \u{201C}%1$@\u{201D} below. Picking an edge "
                + "here puts it there on every screen.",
            appBar
                ? L("kiwishelf.edge.per_screen.app_bar", "Per screen")
                : L("kiwishelf.edge.per_screen.space_bar", "Per screen")
        )
    }

    static func sentence(for reason: BarsGates.InertReason) -> String {
        switch reason {
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
        case .appWideLuaOwned:
            return GeneralGateHelp.sentence(for: .luaOwned)
        }
    }
}
