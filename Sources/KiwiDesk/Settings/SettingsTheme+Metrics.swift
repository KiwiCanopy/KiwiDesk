import CoreGraphics

/// The shape half of `SettingsTheme` — the `CGFloat` metrics,
/// split from the colour table at the §2.1 hard ceiling. Same
/// contract, stated once there: every metric is either wired at
/// a named render site or deferred with a reason
/// (`SettingsThemeMetricTests`, whose census parses THIS file).
extension SettingsTheme {

    // The metrics, and the boundary they are admitted on —
    // stated here, at the head of the section, so the next area
    // meets it by position rather than by archaeology (#758
    // argued it inside one docstring further down, which the
    // second area then cited as "the ruling above" while
    // standing above it).
    //
    // AREA-SCOPED numbers in an app-wide theme, deliberately: a
    // number some arithmetic derives from lives BESIDE that
    // arithmetic (the Monitors picture's capacity maths owns
    // its own), while pure chrome — strokes, radii, stands,
    // things nothing computes on — lives here with the radii so
    // one restyle is one file. "Beside" means the same FILE as
    // the arithmetic: a number declared on a view a file away
    // from what derives with it is indistinguishable at review
    // time from a number dodging the net, so it belongs here.
    // `PaletteSceneThumbnail.plateRadius` is the one that sits
    // outside on purpose — the thumbnail scales it by its own
    // `scale`, which is arithmetic in that file, and the tile's
    // inset derives FROM it.
    //
    // The colour tokens' totality guard cannot see these: it
    // parses `= token(` (`SettingsThemeTokenTests`,
    // `SettingsThemeWiringTests`). Metrics are covered by their
    // area's own chrome suite instead —
    // `MonitorsChromeWiringTests`, `PaletteShelfChromeTests` —
    // and `SettingsThemeMetricTests` is what refuses a metric
    // that belongs to neither, so a third area cannot add one
    // and quietly leave it unguarded.

    /// A Home card's corner. The prototype's cards are flat —
    /// fill plus hairline, no shadow — so the radius carries the
    /// softness a shadow would have.
    static let cardRadius: CGFloat = 14

    /// The two Home card heights (#786) — deliberate, not a
    /// residue: every profile card carries the 92 pt desktop
    /// plate and a whole-app card never does, so one shared
    /// height would either stretch the text cards around
    /// absent pictures or crush the plates.
    /// `HomeCardChromeTests` names the pair together, pins
    /// both values, and holds the tall one above the plate
    /// plus a minimum text band.
    static let cardHeight: CGFloat = 152
    static let cardHeightCompact: CGFloat = 105

    /// The desktop plate's height inside a profile card —
    /// full-bleed to the card's edges, clipped through the
    /// card's own corners, so the card border IS the picture's
    /// visible edge (4g).
    static let plateHeight: CGFloat = 92

    /// The detail panel's fixed column width (digest §1.1 /
    /// turn 2a). Fixed rather than flexible: the CONTENT column
    /// is the one that flexes, so the preview keeps one scale
    /// everywhere and the responsive pass can reason about a
    /// constant — which is also why this stays ONE number rather
    /// than becoming per-area.
    ///
    /// The prototype drew every panel at 392, and four of the
    /// five previews are happy there. Pass 5's keyboard is not:
    /// it is the first panel content with an intrinsic aspect
    /// ratio, and 392 squeezed a 15-unit board to a 19 pt key
    /// unit — under the 26 pt the caps stand, so the board read
    /// as a squashed picture of a keyboard rather than a small
    /// one (owner on device, 2026-08-10). 492 is that back-solved
    /// rather than felt: `15·26 + 14·3 + 2·8 + 2·22`.
    static let panelWidth: CGFloat = 492

    /// The content column's ceiling (owner 2026-08-10): the
    /// prototype's widest content column measures ~970 pt at
    /// the 1440 canvas, and nothing was ever drawn wider — at
    /// full screen an uncapped column stretches every row past
    /// readability. The column centres in the surplus; the
    /// responsive pass owns everything BELOW the breakpoints,
    /// this owns the top end.
    static let contentMaxWidth: CGFloat = 980

    /// A section container's corner. Larger than a card's on
    /// purpose: a section is the outer box, and equal radii make
    /// nested rounds read as a mistake.
    static let sectionRadius: CGFloat = 16

    /// A disclosure interior's corner, one step inside a section.
    static let disclosureRadius: CGFloat = 12

    /// A chip's corner. Rounded-rect, not a capsule — the
    /// prototype's chips are square-ish tokens, and a capsule
    /// beside a segmented control reads as a second control.
    static let chipRadius: CGFloat = 9

    /// The Monitors picture's card stroke at rest — heavier than
    /// the app's hairline so a display card reads as an OBJECT
    /// on the recessed well rather than as outlined content
    /// (#758). Selection keeps its own, still-heavier weight:
    /// the border is the SELECTED channel, and the two weights
    /// must stay apart or one state swallows the other.
    static let monitorCardStroke: CGFloat = 1.5
    static let monitorCardStrokeSelected: CGFloat = 3

    /// A palette tile's frame at rest and once it is the applied
    /// one (#757). The shelf's whole content is colour, so the
    /// frame is the ONLY channel selection can use — no fill, no
    /// glyph on the picture — and the two weights follow the
    /// Monitors picture's ruling above: keep them apart or one
    /// state swallows the other. Lighter than a display card's
    /// pair because a palette tile is one of many in a grid
    /// rather than an object on a well.
    static let paletteCardStroke: CGFloat = 1
    static let paletteCardStrokeApplied: CGFloat = 2

    /// The mode-gateable container shapes' border — the three
    /// that take `modeGated` (`HomeCard`, `SettingsSection`,
    /// `SettingsDisclosure.card`) — at rest and when their
    /// PRESENCE is mode-gated, i.e. the container would leave
    /// the page in Simple (#760). Sibling cards that cannot be
    /// mode-gated keep `strokeBorder`'s implicit default and
    /// are deliberately outside this token. The gated frame
    /// pairs the weight step with the ACCENT at
    /// `modeGatedStrokeOpacity` — weight alone on the hairline
    /// was invisible on device, and a stronger neutral said
    /// "different" without saying which (owner + ui-designer,
    /// 2026-08-09) — while the weight stays below the DOUBLING
    /// the two pairs above spend on chosen things: a mode-gated
    /// card is present, not picked. The flag each site passes
    /// derives from its own offer predicate evaluated at
    /// `.simple` — never a hand-negated copy beside the stroke.
    /// `ModeGatedChromeTests` holds the pair, the predicates
    /// and the derived membership;
    /// `ModeGatedFrameSeparationTests` the frame's CVD floors.
    static let containerStroke: CGFloat = 1
    static let containerStrokeModeGated: CGFloat = 1.5

    /// The mode-gated frame's accent strength. 0.6 measured,
    /// not felt (ui-designer, 2026-08-09, Viénot protanopia
    /// over the composited stroke): 0.5 landed the light-mode
    /// gated-vs-plain pair at CVD separation 60 — exactly the
    /// floor — while 0.6 sits at 82/100 (light/dark) from the
    /// hairline AND 81 from hover's full accent in both
    /// appearances, the midpoint of the register space; at 0.7
    /// the hover register collapses to 61.
    /// `ModeGatedFrameSeparationTests` derives those floors
    /// from the shipped tokens rather than restating them.
    static let modeGatedStrokeOpacity: CGFloat = 0.6

    /// A display card's stand: the foot as a share of the card's
    /// width and the neck as a share of the foot, each clamped.
    /// Long enough that the card sits ON its foot rather than
    /// floating above a speck (#758); the clamps stop the same
    /// shares giving a laptop thumbnail a plinth. The foot's
    /// FLOOR stays at its pre-#758 value: on a floor-sized card
    /// (`MonitorArrangement.minimumCard`) the raised share
    /// alone reads as a plinth, and neighbouring floored cards'
    /// feet fuse into one rail (ui-designer, 2026-08-09).
    ///
    /// The section header states the boundary these are
    /// admitted on; `MonitorsChromeWiringTests`' themed-metrics
    /// test is this pair's wiring guard, the capacity arithmetic
    /// they are NOT part of living in `MonitorCardChips`.
    static let monitorStandScale: CGFloat = 0.52
    static let monitorStandMin: CGFloat = 44
    // 230 → 320 (owner, 2026-08-09): on a wide single-display
    // card the old cap cut the foot to well under half the
    // screen while the Home tile — unclamped shares — kept the
    // full relation, and the two pictures of one desk disagreed.
    static let monitorStandMax: CGFloat = 320
    static let monitorNeckScale: CGFloat = 0.26
    static let monitorNeckMin: CGFloat = 14
    static let monitorNeckMax: CGFloat = 44
}
