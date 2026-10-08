import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The count pill's ring is drawn only where it is needed (#1946,
/// owner ruling): where the badge fill separates from the peek's
/// grounds — the stored Fill and the Fill as glass caps it — by less
/// than `KiwiShelf.peekPillRingFloor`, over either wallpaper extreme.
@Suite("Hover peek pill ring", .serialized)
@MainActor
struct PeekPillRingTests {
    private static let wallpapers = ["#FFFFFF", "#000000"]

    /// The badge fill's worst separation from the plate, measured
    /// here on `ColorVision` beside the derivation, not through it.
    private func separation(
        _ shelf: KiwiShelf,
        storedOnly: Bool = false
    ) -> Double? {
        var worst: Double?
        let grounds =
            storedOnly
            ? [shelf.fillColor]
            : [shelf.fillColor, shelf.fill(cappedAt: GlassTint.maxAlpha)]
        for ground in grounds {
            for wallpaper in Self.wallpapers {
                guard
                    let plate = ColorVision.composite(ground, over: wallpaper),
                    let pill = ColorVision.composite(
                        shelf.groupBadgeColor,
                        over: plate
                    ),
                    let ratio = ColorVision.contrast(pill, plate)
                else { return nil }
                worst = min(worst ?? ratio, ratio)
            }
        }
        return worst
    }

    private func painted(_ palette: ColorPalette) -> KiwiShelf {
        var settings = TilingSettings()
        palette.apply(to: &settings)
        return settings.kiwishelf
    }

    @Test("Every bundled palette's ring verdict is the derivation's")
    func bundledVerdicts() throws {
        var verdicts: [String] = []
        for palette in PaletteCatalog.bundled() {
            let shelf = painted(palette)
            let worst = try #require(separation(shelf))
            let needs = worst < KiwiShelf.peekPillRingFloor
            #expect(
                shelf.peekPillNeedsRing == needs,
                Comment(rawValue: "\(palette.name): \(worst)")
            )
            verdicts.append(
                "\(palette.name)=\(needs ? "ring" : "none")"
                    + String(format: "(%.2f)", worst)
            )
        }
        #expect(!verdicts.isEmpty)
        print("peek pill ring verdicts: \(verdicts.joined(separator: " "))")
    }

    @Test("A badge fill near the plate draws the ring; a far one none")
    func fixturesDecide() {
        var near = KiwiShelf()
        near.fillColor = "#202020FF"
        near.groupBadgeColor = "#262626"
        #expect(near.peekPillNeedsRing)
        #expect(
            BarPeekPill(2, shelf: near).layer?.borderWidth
                == BarPeekBody.Metrics.pillRing
        )
        var far = KiwiShelf()
        far.fillColor = "#000000FF"
        far.groupBadgeColor = "#FFFFFF"
        #expect(!far.peekPillNeedsRing)
        #expect(BarPeekPill(2, shelf: far).layer?.borderWidth == 0)
    }

    /// An opaque black Fill holds a mid-grey badge apart; the same
    /// Fill as glass caps it, over white, does not. Only the glass
    /// ground fails the floor, so the ring is that ground's alone.
    @Test("A badge only the glass ground fails still draws the ring")
    func glassGroundAloneDrawsTheRing() throws {
        var shelf = KiwiShelf()
        shelf.fillColor = "#000000FF"
        shelf.groupBadgeColor = "#8A8A8A"
        let stored = try #require(separation(shelf, storedOnly: true))
        let worst = try #require(separation(shelf))
        #expect(stored >= KiwiShelf.peekPillRingFloor, "\(stored)")
        #expect(worst < KiwiShelf.peekPillRingFloor, "\(worst)")
        #expect(shelf.peekPillNeedsRing)
        #expect(
            BarPeekPill(2, shelf: shelf).layer?.borderWidth
                == BarPeekBody.Metrics.pillRing
        )
    }

    /// The pill reads the one verdict: every bundled palette's pill
    /// draws exactly the ring the derivation asks for — and, since
    /// every bundled palette needs it, a fixture needing none draws
    /// none.
    @Test("The pill's ring follows the derivation")
    func pillFollowsTheVerdict() throws {
        var far = KiwiShelf()
        far.fillColor = "#000000FF"
        far.groupBadgeColor = "#FFFFFF"
        var shelves = PaletteCatalog.bundled().map {
            ($0.name, painted($0))
        }
        shelves.append(("no-ring fixture", far))
        for (name, shelf) in shelves {
            let worst = try #require(separation(shelf))
            let expected: CGFloat =
                worst < KiwiShelf.peekPillRingFloor
                ? BarPeekBody.Metrics.pillRing : 0
            #expect(
                BarPeekPill(3, shelf: shelf).layer?.borderWidth == expected,
                Comment(rawValue: name)
            )
        }
        #expect(BarPeekPill(3, shelf: far).layer?.borderWidth == 0)
    }
}
