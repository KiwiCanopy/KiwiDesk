import AppKit
import Testing

@testable import KiwiDeskCore

/// **"Fill fade" sets how far the Fill fades across a glass**
/// (#2569 ▸ Ruling): 100 is the far end at `floorShare` of the
/// anchor, 0 one even colour, never fully clear (#1622). The shelf
/// mints one `GlassFill` its glass surfaces paint.
@Suite("Glass Fill fade (#2569)")
@MainActor
struct GlassFillFadeTests {
    /// Reduce transparency is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    private static let frame = CGRect(x: 0, y: 0, width: 80, height: 24)

    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// The far end's alpha as a share of the anchor's.
    private static func farShare(_ backdrop: GlassBackdrop) -> CGFloat? {
        let colors = backdrop.gradient?.colors as? [CGColor] ?? []
        guard colors.count == 2, colors[0].alpha > 0 else { return nil }
        return colors[1].alpha / colors[0].alpha
    }

    private static func painted(fade: CGFloat) -> CGFloat? {
        let glass = NSView(frame: frame)
        let backdrop = GlassBackdrop(frame: frame)
        GlassTint.apply(
            backdrop,
            in: glass,
            cornerRadius: 4,
            fill: GlassFill(hex: "#14201CB3", fade: fade),
            edge: .top
        )
        return farShare(backdrop)
    }

    @Test(
        "The far end follows the fade",
        arguments: [
            (100.0, GlassTint.floorShare), (0.0, 1.0),
            (50.0, (1 + GlassTint.floorShare) / 2),
        ]
    )
    func farEndFollowsTheFade(fade: Double, share: CGFloat) throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let painted = try #require(Self.painted(fade: fade))
        #expect(abs(painted - share) < 0.001, "\(fade): \(painted)")
    }

    @Test("A reading floor stops the fade at its share")
    func readingFloorStopsTheFade() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let glass = NSView(frame: Self.frame)
        let backdrop = GlassBackdrop(frame: Self.frame)
        GlassTint.apply(
            backdrop,
            in: glass,
            cornerRadius: 4,
            fill: GlassFill(hex: "#14201CB3", fade: 100, minShare: 0.6),
            edge: .top
        )
        let share = try #require(Self.farShare(backdrop))
        #expect(abs(share - 0.6) < 0.001, "\(share)")
    }

    /// "Tint KiwiHub and plates" (#2569 ▸ Ruling): on by default,
    /// a boolean everywhere it is written.
    @Test("The plates' tint toggle stores and sets")
    func tintToggleStoresAndSets() throws {
        #expect(KiwiShelf().tintHubAndPlates)
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(#"{"tint_hub_and_plates": false}"#.utf8)
        )
        #expect(!shelf.tintHubAndPlates)
        var set = KiwiShelf()
        try KiwiShelfCommandSetting.parse(
            field: "tint_hub_and_plates",
            args: [.bool(false)]
        ).get().apply(to: &set)
        #expect(!set.tintHubAndPlates)
    }

    @Test("A surface's own colour keeps today's fade")
    func ownColourKeepsTheFade() {
        #expect(GlassFill(hex: "#FF0000").fade == 100)
    }

    @Test(
        "The stored fade clamps to 0–100",
        arguments: [(-5.0, 0.0), (150.0, 100.0), (40.0, 40.0)]
    )
    func decodeClamps(stored: Double, kept: Double) throws {
        let json = #"{"fill_fade": \#(stored)}"#
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(json.utf8)
        )
        #expect(shelf.fillFade == CGFloat(kept))
        #expect(KiwiShelf().fillFade == 100)
    }

    @Test(
        "The setter clamps to 0–100",
        arguments: [(-5.0, 0.0), (150.0, 100.0), (40.0, 40.0)]
    )
    func setterClamps(value: Double, kept: Double) throws {
        let setting = try KiwiShelfCommandSetting.parse(
            field: "fill_fade",
            args: [.number(value)]
        ).get()
        var shelf = KiwiShelf()
        setting.apply(to: &shelf)
        #expect(shelf.fillFade == CGFloat(kept))
    }

    /// The consumer: the shelf's plate paints the shelf's fade.
    @Test("The shelf's plate paints its fade")
    func shelfPlatePaintsTheFade() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3, glass: true)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        var shelf = KiwiShelf()
        shelf.liquidGlass = true
        shelf.fillFade = 0
        let shelves = ShelfManager()
        shelves.sync([
            ShelfManager.Shelf(
                display: barTitleDisplay,
                edge: .top,
                strip: barTitleStrip,
                shelf: shelf,
                sheen: 0,
                space: section,
                app: nil
            )
        ])
        let overlay = try #require(
            shelves.overlayForTesting(barTitleDisplay)
        )
        let tint = try #require(overlay.glassTint)
        let share = try #require(Self.farShare(tint))
        #expect(abs(share - 1) < 0.001, "\(share)")
    }

    /// The consumer: a boxed Space Bar's boxes paint the fade.
    @Test("A boxed Space Bar's boxes paint the fade")
    func boxesPaintTheFade() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        var bar = paintedSpaceBar(front: WindowID(1), spaces: 2)
        var style = bar.style
        style.liquidGlass = true
        style.backgroundStyle = .boxed
        style.fillFade = 0
        bar = SpaceBarManager.Bar(
            display: bar.display,
            items: bar.items,
            frontApp: bar.frontApp,
            frontWindow: bar.frontWindow,
            strip: bar.strip,
            style: style,
            stateMarkColors: bar.stateMarkColors
        )
        let manager = SpaceBarManager()
        manager.sync([bar])
        let overlay = try #require(manager.shownOverlay(on: barTitleDisplay))
        let tints = overlay.boxTints + [overlay.frontTint].compactMap { $0 }
        try #require(!tints.isEmpty, "no box was tinted")
        for tint in tints {
            let share = try #require(Self.farShare(tint))
            #expect(abs(share - 1) < 0.001, "\(share)")
        }
    }
}
