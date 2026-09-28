import AppKit
import Testing

@testable import KiwiDeskCore

/// The front-app chip and the App Bar's horizontal slots take the
/// same clearance at their rounded ends (#1763), each handing
/// `KiwiShelf.endClearance` its own cross offset, and measure what
/// they lay out. The vertical App Bar is out of scope by ruling.
@Suite("Rounded chip and App Bar ends pad the axis", .serialized)
@MainActor
struct RoundedItemEndPadChipTests {
    private typealias Fixture = RoundedItemEndPadTests
    private static let depth = Fixture.depth

    init() { LiquidGlassGate.override = { false } }

    // MARK: - The front-app chip

    @Test("The front-app chip pads its rounded ends")
    func frontChipPadsItsEnds() throws {
        for depth in [Self.depth, 80] {
            for roundness in Fixture.roundnesses {
                let look = Fixture.spaceLook(roundness)
                let end =
                    SpaceBarItemView.pad
                    + Fixture.clearance(look, depth: depth)
                let overlay = try Fixture.spaceBar(
                    look,
                    items: Fixture.items(1),
                    depth: depth,
                    front: Fixture.app("Claude")
                )
                #expect(overlay.chipEndPad(look, depth: depth) == end)
                #expect(!overlay.frontBox.isHidden)
                let box = overlay.frontBox.frame
                let icon = overlay.frontIcon.frame
                let name = overlay.frontName.frame
                #expect(abs(icon.minX - box.minX - end) <= 0.5)
                #expect(abs(box.maxX - name.maxX - end) <= 0.5)
            }
        }
    }

    /// A title cut at the viewport keeps the chip's rounded end
    /// inside it rather than running its end pad past.
    @Test("A truncated front title keeps the chip inside the viewport")
    func truncatedTitleKeepsTheChipIn() throws {
        let width: CGFloat = 420
        let look = Fixture.spaceLook(100)
        var front = Fixture.app("Claude")
        front.title = String(repeating: "A long window title ", count: 12)
        let overlay = try Fixture.spaceBar(
            look,
            items: Fixture.items(1),
            front: front,
            width: width
        )
        let name = overlay.frontName
        let full = ceil(
            ((front.title ?? "") as NSString).size(
                withAttributes: [.font: name.font as Any]
            ).width
        )
        #expect(name.frame.width < full, "the fixture must truncate")
        let box = overlay.frontBox.frame
        let end = overlay.chipEndPad(look, depth: Self.depth)
        #expect(abs(box.maxX - name.frame.maxX - end) <= 0.5)
        #expect(box.maxX <= width + 0.5)
    }

    // MARK: - The App Bar

    private static func appLook(
        _ roundness: CGFloat,
        boxed: Bool = true
    ) -> AppBarLook {
        var look = AppBarLook()
        look.shelf = Fixture.shelf(roundness, boxed: boxed)
        look.edge = .top
        look.content = .iconAndTitle
        return look
    }

    /// The App Bar's content square is the content depth less its
    /// padding, centred across the strip.
    private static func clearance(
        _ look: AppBarLook,
        depth: CGFloat
    ) -> CGFloat {
        let side =
            look.contentDepth(forDepth: depth)
            - 2 * AppBarItemView.contentPadding
        return KiwiShelf.endClearance(
            radius: look.resolvedCornerRadius(forThickness: depth),
            crossOffset: (depth - side) / 2
        )
    }

    private func appItem(
        width: CGFloat,
        look: AppBarLook,
        depth: CGFloat = depth,
        first: Bool = true,
        last: Bool = true
    ) -> AppBarItemView {
        let view = AppBarItemView(
            frame: CGRect(x: 0, y: 0, width: width, height: depth)
        )
        view.configure(
            id: WindowID(1),
            text: "Downloads",
            icon: Fixture.icon(),
            glyph: nil,
            count: 1,
            active: true,
            horizontal: true,
            style: look
        )
        view.isFirstInRun = first
        view.isLastInRun = last
        view.layout()
        return view
    }

    private static func slot(
        _ look: AppBarLook,
        depth: CGFloat,
        count: Int = 1
    ) -> CGFloat {
        AppBarOverlay.slot(
            items: (1...count).map {
                appBarItem(UInt32($0), text: "Downloads")
            },
            style: look,
            thickness: depth,
            capAxis: 4000
        )
    }

    @Test("An App Bar slot measures the end padding it lays out")
    func appSlotMeasuresWhatItDraws() {
        for depth in [Self.depth, 80] {
            let square = Self.slot(Self.appLook(0), depth: depth)
            for roundness in Fixture.roundnesses {
                let look = Self.appLook(roundness)
                let e = Self.clearance(look, depth: depth)
                let ends = AppBarItemView.endPadding(
                    look,
                    depth: depth,
                    first: true,
                    last: true
                )
                #expect(ends.leading == AppBarItemView.edgePadding + e)
                #expect(ends.trailing == AppBarItemView.edgePadding + e)
                // Read apart from the layout, which clamps to any width.
                let slot = Self.slot(look, depth: depth)
                #expect(abs(slot - square - 2 * e) < 1e-9)
                let view = appItem(width: slot, look: look, depth: depth)
                let title = ceil(view.label.cell?.cellSize.width ?? 0)
                #expect(view.label.frame.width >= title)
                #expect(abs(view.iconView.frame.minX - ends.leading) <= 0.5)
                #expect(
                    abs(slot - view.label.frame.maxX - ends.trailing)
                        <= 0.5,
                    "depth \(depth), roundness \(roundness)"
                )
            }
        }
    }

    /// A slot capped short of its title truncates the title at the
    /// end padding rather than into the rounded end.
    @Test("A capped App Bar slot keeps the end padding")
    func cappedAppSlotKeepsThePadding() {
        for roundness in Fixture.roundnesses {
            let look = Self.appLook(roundness)
            let ends = AppBarItemView.endPadding(
                look,
                depth: Self.depth,
                first: true,
                last: true
            )
            let view = appItem(width: 96, look: look)
            #expect(!view.label.isHidden)
            #expect(abs(view.iconView.frame.minX - ends.leading) <= 0.5)
            #expect(abs(96 - view.label.frame.maxX - ends.trailing) <= 0.5)
        }
    }

    /// On a plate a middle slot draws no rounded end; the run's
    /// first and last carry the clearance at their outer end only.
    @Test("On a plate only the App Bar run's outer ends pad")
    func plateSlotsPadOnlyTheRunEnds() {
        let look = Self.appLook(100, boxed: false)
        let e = Self.clearance(look, depth: Self.depth)
        #expect(e > 0)
        let edge = AppBarItemView.edgePadding
        let places: [(Bool, Bool, ItemEnds)] = [
            (true, false, ItemEnds(leading: edge + e, trailing: edge)),
            (false, false, ItemEnds(leading: edge, trailing: edge)),
            (false, true, ItemEnds(leading: edge, trailing: edge + e)),
        ]
        // Three alike items: the slot is the run's widest, an end's.
        let slot = Self.slot(look, depth: Self.depth, count: 3)
        let square = Self.slot(
            Self.appLook(0, boxed: false),
            depth: Self.depth,
            count: 3
        )
        #expect(abs(slot - square - e) < 1e-9)
        for (first, last, expected) in places {
            let ends = AppBarItemView.endPadding(
                look,
                depth: Self.depth,
                first: first,
                last: last
            )
            #expect(ends == expected)
            let view = appItem(
                width: slot,
                look: look,
                first: first,
                last: last
            )
            #expect(view.iconView.frame.minX >= ends.leading - 0.5)
            #expect(view.label.frame.maxX <= slot - ends.trailing + 0.5)
            let title = ceil(view.label.cell?.cellSize.width ?? 0)
            #expect(view.label.frame.width >= title)
        }
    }
}
