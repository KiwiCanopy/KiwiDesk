import Foundation

/// `BarMotionSeamTests`' census of the home files' members and the
/// rulings that keep motion ungated, split from the suite at the
/// §2.1 ceiling.
extension BarMotionSeamTests {
    /// Every member of the home file, paired with what its body
    /// must name. **The census is the fail-shut half**: a member
    /// added to `BarMotion` reds until it is written down here,
    /// which is what a hand-listed case list could not do — the
    /// routing clause exempts the home file by design, so a
    /// fourth ungated wrapper was invisible to every test in
    /// both suites (guard-prover).
    ///
    /// An empty list claims the member starts no motion, and the
    /// clause refuses that claim for one that does — so a new
    /// starter cannot be admitted quietly, only with the gate it
    /// names written beside it.
    ///
    /// It lists the members that OPEN A BODY, which is what
    /// `memberBodies` returns: `slide` is a stored `let` and is
    /// deliberately absent. That is the walker's stated residue
    /// arriving here — a stored property whose initializer is a
    /// closure could start motion out of this clause's reach —
    /// and it is why `motionHasOneHome` scans the file's whole
    /// text rather than only its members.
    static let members: [String: [String]] = [
        "isReduced": [],
        "pocketRiseTravel": [],
        "playPocketRise": ["pocketRise(", "isReduced"],
        "pocketRise": ["reduceMotion"],
        "pocketRiseStart": [],
        "playPocketEntrance": ["pocketEntrance(", "isReduced"],
        "pocketEntrance": ["reduceMotion"],
        "playPocketLight": ["pocketLightDuration(", "isReduced"],
        "pocketLightDuration": ["reduceMotion"],
        "pocketEase": ["duration"],
        "playPocketNod": ["pocketNod(", "isReduced"],
        "pocketNod": ["reduceMotion"],
        "runLayout": ["duration(", "isReduced"],
        "duration": [],
        "runPlateGlide": ["shelfGlide", "expanding("],
        "setFrame": ["travels(", "isReduced"],
        "setAlpha": ["fades(", "isReduced"],
        "fades": [],
        "fadePeek": ["peekFadeDuration(", "isReduced", "peekMotion"],
        "peekFadeDuration": ["fades(", "onPeek"],
        "afterGroupGlide": ["shelfGlide"],
        "shelfGlideLength": ["shelfGlide"],
        "standCommitted": [],
        "runDissolveOut": ["dissolveOutDuration(", "expanding("],
        "dissolveOutDuration": [],
        "playWalk": ["walkDuration(", "isReduced"],
        "walkDuration": [],
        "walkAnimation": ["duration"],
        "travels": [],
        "springSweep": ["springAnimation(", "isReduced"],
        "springAnimation": ["reduceMotion"],
        "opacityFade": ["reduceMotion"],
        "slideSpring": ["reduceMotion"],
        "revealOffset": [],
        "revealShift": [],
        "revealMotion": [],
        "resolvedReveal": ["revealMotion("],
        "playReveal": ["revealMotion("],
        "afterCommit": [],
        "endReveal": ["endSpread("],
        "afterReveal": [],
        "markFade": [],
        "fadeMark": ["markFade("],
        "hoverPlate": [],
        "hoverShift": [],
        "horizontal": [],
        "placeHoverPlate": ["hoverGrow"],
        "clipPlace": [],
        "expanding": [],
        "settling": [],
        "revealScale": [],
        "length": [],
        "naturalLength": [],
        "playUnfold": ["unfoldStretch(", "itemsRise("],
        "unfoldStretch": [],
        "unfoldCollapse": [],
        "itemsRise": [],
        "scaled": [],
        "spreadUnits": [],
        "playSpread": [],
        "spreadFade": [],
        "endSpread": [],
        "morphPlay": [],
        "playMorph": ["morphPlay(", "isReduced", "peekMotion"],
        "endMorph": [],
        "morphClip": ["span"],
        "morphFade": ["span"],
    ]

    /// Members whose motion Reduce Motion deliberately KEEPS, each
    /// naming its ruling — the one copy of who is ungated. The owner
    /// ruled the shelf's reveal (every style), the hidden mark's
    /// hover growth and the shelf's expand motions that play
    /// regardless, as the
    /// Dock's auto-hide slides under Reduce Motion (2026-10-21,
    /// `docs/design-decisions.md` ▸ The bars honour Reduce Motion).
    /// A member here may start motion with no gate, and may not read
    /// the flag: a ruled member that reads it again is a ruling that
    /// fires on nothing.
    static let ungated: [String: String] = [
        "playReveal": "the reveal plays under Reduce Motion (owner)",
        "playUnfold": "the unfold plays under Reduce Motion (owner)",
        "unfoldStretch": "the unfold's stretch, the same ruling",
        "unfoldCollapse": "the unfold's collapse, the same ruling",
        "itemsRise": "the unfold's items, the same ruling",
        "playSpread": "the Boxed unfold plays under Reduce Motion",
        "spreadFade": "the Boxed unfold's fade, the same ruling",
        "fadeMark": "the mark keeps the reveal's time (owner)",
        "placeHoverPlate": "the hover growth plays under Reduce Motion",
        "runPlateGlide": "the shelf's expand plays under Reduce Motion",
        "runDissolveOut": "the expand's dissolve, the same ruling",
        "settling": "builds a spring to read its length, plays none",
    ]
}
