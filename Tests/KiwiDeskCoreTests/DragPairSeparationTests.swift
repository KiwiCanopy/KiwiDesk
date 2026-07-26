import Foundation
import Testing

@testable import KiwiDeskCore

/// The colour-vision clause applied to the drag overlay (#511).
///
/// During a drag two overlays are on screen at once: the **ghost**
/// (origin — the window under the cursor) and the **drop zone**
/// (target — where it will land). `docs/design-decisions.md` says
/// they read apart by hue. They did not, under red-green vision
/// loss: the shipped default measured **4.7/441**, worse than the
/// 22 that #470 called "the same colour to a protanope", and
/// Clean Light, Slate and True Dark shipped origin and target as
/// literally the *same hex* — indistinguishable for everyone.
///
/// Same metric and same floor as the Space Bar's accent pair, on
/// purpose. Motion is a real redundant cue here that the Space
/// Bar has none of (the ghost tracks the cursor, the drop zone
/// stays put), so a lower floor would be arguable — but the two
/// are frequently adjacent, a user resolves which-is-which from a
/// near-static glance, and CVD grants no compensating boost to
/// motion discrimination. A second threshold to explain and guard
/// buys nothing when a hex clearing the shared one was available.
///
/// What this does *not* cover: contrast against the window
/// content underneath. There is no fixed background to measure
/// against — see the overlay row in `docs/accepted-limitations.md`
/// for why that stays an accepted limitation.
@Suite("Overlay color separation and contrast")
struct DragPairSeparationTests {
    /// Why the ghost left the focus ring's hue family (#511).
    ///
    /// This exists because the prose version of this argument was
    /// written wrong three times running. Every figure in the
    /// origin/target paragraph of `docs/design-decisions.md` that
    /// survived review is one a test pins; every figure that had
    /// to be retracted was prose-only. So the claim is pinned
    /// here and the prose cites it.
    ///
    /// The trade is **chroma against separation**, not
    /// impossibility: the ring's hue family does contain colours
    /// satisfying all three constraints, they just cannot be
    /// saturated. Anyone re-deriving this: sweep HSL over the
    /// stated hue band, and impose all three constraints at once
    /// (separation ≥ floor against the drop-zone amber, ≥3:1 on
    /// near-white *and* near-black). Sweeping with a saturation
    /// floor of your own makes the qualifying set look like it
    /// clusters there — that is the mistake this test is here to
    /// stop repeating.
    @Test("The ring's hue family cannot do the ghost's job")
    func ringHueFamilyCannotSeparateAtChroma() throws {
        let target = DragVisual.dropZoneDefault.borderColor
        func qualifies(_ hex: String) -> Bool {
            guard
                let gap = ColorVision.separation(hex, target),
                let onWhite = ColorVision.contrast(hex, "#FFFFFF"),
                let onBlack = ColorVision.contrast(hex, "#000000")
            else { return false }
            return gap >= ColorVision.separationFloor
                && onWhite >= 3 && onBlack >= 3
        }
        // At the ring's own hue AND its own saturation, no
        // lightness works. This is the load-bearing claim: the
        // ghost could not simply be a darker or lighter #588613.
        for step in 0...100 {
            let candidate = ColorVision.hex(
                hue: 84,
                saturation: 0.75,
                lightness: Double(step) / 100
            )
            #expect(
                !qualifies(candidate),
                Comment(rawValue: "\(candidate) unexpectedly works")
            )
        }
        // Drop to the shipped ghost's chroma and the ring's hue
        // does qualify — but barely, where the emerald clears the
        // floor with room. That gap is the whole argument.
        let matchedChroma = "#799D43"
        #expect(qualifies(matchedChroma))
        let ringHue = try #require(
            ColorVision.separation(matchedChroma, target)
        )
        let shipped = try #require(
            ColorVision.separation(
                DragVisual.ghostDefault.borderColor,
                target
            )
        )
        #expect(abs(ringHue - 61) < 3)
        #expect(abs(shipped - 76) < 3)
        // And the yellow-green that *did* clear separation well
        // (85) failed the contrast bar instead — the rejected
        // alternative, kept here so the trade stays visible.
        let rejected = try #require(
            ColorVision.contrast("#2F4A0C", "#000000")
        )
        #expect(rejected < 3)
    }

    @Test("The shipped drag pair survives red-green vision loss")
    func defaultPairSeparatesUnderProtanopia() throws {
        let ghost = DragVisual.ghostDefault.borderColor
        let zone = DragVisual.dropZoneDefault.borderColor
        let gap = try #require(ColorVision.separation(ghost, zone))
        // Was 4.7 while both were the ring's yellow-green against
        // the drop-zone amber. The target is locked — that amber
        // is the hex `SpaceBarStyle.focusedItemColor` converged
        // onto in #470 — so it is the *ghost* that moved, and it
        // had to leave the hue family to do it. See
        // `DragVisual.ghostDefault`.
        let detail =
            "ghost \(ghost) vs drop zone \(zone) separate by only "
            + "\(gap)/441 under simulated protanopia (#511)"
        #expect(
            gap >= ColorVision.separationFloor,
            Comment(rawValue: detail)
        )
    }

    @Test("Both overlays clear 3:1 on near-white and near-black")
    func overlaysHoldTheirContrastFloor() throws {
        // The constraint that picked the ghost's hue. `#2F4A0C`
        // separated better (85) but fell to 2.11:1 on near-black,
        // and the overlay row in docs/accepted-limitations.md
        // rests on the overlay clearing 3:1 at *both* ends — that
        // is the whole mitigation for painting over arbitrary
        // window content. The ring is in this loop because the
        // same row names it, and it is the likelier of the two to
        // move (it went `#567A1F` → `#588613` in the #358 batch).
        let overlays = [
            DragVisual.ghostDefault.borderColor,
            BorderStyle().focusedColor,
        ]
        for overlay in overlays {
            for backdrop in ["#FFFFFF", "#000000"] {
                let ratio = try #require(
                    ColorVision.contrast(overlay, backdrop)
                )
                #expect(
                    ratio >= 3,
                    Comment(
                        rawValue:
                            "\(overlay) on \(backdrop): \(ratio):1"
                    )
                )
            }
        }
    }

    @Test("Every bundled drag pair survives red-green vision loss")
    func everyBundledPairSeparatesUnderProtanopia() throws {
        let palettes = PaletteCatalog.bundled()
        // `PaletteCatalog.authored()` soft-fails to `[]`, so
        // without this the sweep silently shrinks to the derived
        // default and still passes.
        #expect(palettes.count == 9)
        for palette in palettes {
            let name = palette.name
            // Every palette carries drag keys, the derived default
            // included: `ColorPaletteKeys.all` builds them by
            // reflection over `DragVisual.CodingKeys` under both
            // prefixes, and `ColorPaletteTests` pins all 23 keys
            // resolving. So a missing one is a real regression,
            // recorded rather than skipped — matching the sibling
            // sweep in `SpaceBarAccentSeparationTests`.
            guard
                let ghost =
                    palette.colors["drag.ghost.border_color"],
                let zone =
                    palette.colors["drag.drop_zone.border_color"]
            else {
                Issue.record("\(name) omits a drag color key")
                continue
            }
            // Opacity, for the same reason the accent sweep pins
            // it — and the risk is higher here: `fill_color` is
            // alpha-bearing by design and sits one line away from
            // `border_color` in every palette.
            for hex in [ghost, zone] {
                let rgb = DragVisual.parseHex(hex)
                #expect(
                    rgb?.alpha == 1,
                    Comment(rawValue: "\(name) \(hex) is not opaque")
                )
            }
            guard let gap = ColorVision.separation(ghost, zone) else {
                Issue.record("\(name) has an unparseable drag color")
                continue
            }
            let detail =
                "\(name): ghost \(ghost) vs drop zone \(zone) "
                + "separate by only \(gap)/441 under simulated "
                + "protanopia (#511)"
            #expect(
                gap >= ColorVision.separationFloor,
                Comment(rawValue: detail)
            )
        }
    }
}
