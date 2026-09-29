import AppKit
import Testing

@testable import KiwiDeskCore

/// An item paints round exactly the ends it pads (#1763): the
/// layer's corner mask, hover fill included, and the end
/// clearance read one predicate, so a middle item on a plate is
/// square at both ends and a boxed one round at both.
@Suite("Item corners follow the padded ends (#1763)", .serialized)
@MainActor
struct ItemCornerMaskTests {
    private typealias Fixture = RoundedItemEndPadTests

    init() { LiquidGlassGate.override = { false } }

    private static let leading: CACornerMask = [
        .layerMinXMinYCorner, .layerMinXMaxYCorner,
    ]
    private static let trailing: CACornerMask = [
        .layerMaxXMinYCorner, .layerMaxXMaxYCorner,
    ]

    private static func rounds(
        _ layer: CALayer?
    ) throws -> (leading: Bool, trailing: Bool) {
        let mask = try #require(layer).maskedCorners
        return (
            mask.isSuperset(of: leading),
            mask.isSuperset(of: trailing)
        )
    }

    @Test("A Space item rounds only the ends it pads")
    func spaceItemRoundsWhatItPads() throws {
        for boxed in [true, false] {
            let look = Fixture.spaceLook(100, boxed: boxed)
            let overlay = try Fixture.spaceBar(
                look,
                items: Fixture.items(3)
            )
            let views = Array(overlay.itemViews.prefix(3))
            #expect(views.count == 3)
            for (index, view) in views.enumerated() {
                view.restyle()
                let round = try Self.rounds(view.layer)
                let clip = try Self.rounds(view.accentClip.layer)
                let note = Comment(rawValue: "boxed \(boxed) #\(index)")
                #expect(round.leading == (view.ends.leading > 0), note)
                #expect(round.trailing == (view.ends.trailing > 0), note)
                #expect(clip.leading == round.leading, note)
                #expect(clip.trailing == round.trailing, note)
            }
        }
    }

    /// The owner's case (2026-09-29): the active Space's outline is
    /// a capsule on a plate, so every item pads and rounds both
    /// ends, not only the run's — or the outline's trailing curve
    /// meets the last glyph.
    @Test("An outlined plate pads and rounds every Space item's ends")
    func outlinedPlatePadsEveryItem() throws {
        let look = Fixture.spaceLook(100, boxed: false, outlined: true)
        let overlay = try Fixture.spaceBar(look, items: Fixture.items(3))
        let views = Array(overlay.itemViews.prefix(3))
        #expect(views.count == 3)
        for (index, view) in views.enumerated() {
            view.restyle()
            let note = Comment(rawValue: "#\(index)")
            #expect(view.ends.leading > 0, note)
            #expect(view.ends.trailing > 0, note)
            let round = try Self.rounds(view.layer)
            #expect(round.leading && round.trailing, note)
        }
    }

    @Test("An App Bar item rounds only its run's drawn ends")
    func appItemRoundsWhatItPads() throws {
        for boxed in [true, false] {
            var look = AppBarLook()
            look.shelf = Fixture.shelf(100, boxed: boxed)
            look.edge = .top
            look.content = .iconAndTitle
            let manager = AppBarManager()
            manager.sync([
                AppBarManager.Bar(
                    display: barTitleDisplay,
                    space: SpaceID("1"),
                    items: (1...3).map {
                        appBarItem(UInt32($0), text: "Downloads")
                    },
                    activeIndex: 0,
                    strip: Fixture.strip(),
                    style: look,
                    capAxis: 1440
                )
            ])
            let overlay = try #require(
                manager.overlayForTesting(barTitleDisplay)
            )
            let views = overlay.itemViews.filter { !$0.isHidden }
            #expect(views.count == 3)
            for (index, view) in views.enumerated() {
                view.layoutSubtreeIfNeeded()
                view.applyCornerRadius()
                let round = try Self.rounds(view.layer)
                let note = Comment(rawValue: "boxed \(boxed) #\(index)")
                #expect(round.leading == (boxed || index == 0), note)
                #expect(round.trailing == (boxed || index == 2), note)
            }
        }
    }
}
