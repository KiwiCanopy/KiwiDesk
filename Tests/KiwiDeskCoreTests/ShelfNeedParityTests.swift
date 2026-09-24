import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A bar's natural length is what its own render draws (#1517):
/// handed a segment exactly that long, the run fits without an
/// arrow and its plate reaches the segment's GUTTER-side end —
/// the side facing the other bar — so no slack widens the gutter.
/// `naturalLength` restates the render's padding, so this is
/// where the two are held together. The Space run keeps a `pad`
/// at its outer end, so below `item_gap == pad` its gutter side
/// may sit `pad − gap` in; that is the whole allowed slack.
/// Residue, stated: the suite re-runs render's pure steps
/// (`itemLengths` → `runTotal` → `scrollViewport` →
/// `contentStart` → `BarPlate.frame`; `metrics` → `frames` →
/// `BarPlate.frame`) rather than `render` itself, so a change to
/// how `render` composes them — a new inset at the call site —
/// stays green here.
@Suite("Shelf need parity (#1517)")
@MainActor
struct ShelfNeedParityTests {
    private let depth: CGFloat = 40

    nonisolated private static let placements:
        [(KiwiShelf.Alignment, CGFloat)] =
            [(.start, 2), (.start, 6), (.end, 2), (.end, 6)]

    @Test(
        "the Space run fills its natural segment",
        arguments: ShelfNeedParityTests.placements
    )
    func spaceRunFits(alignment: KiwiShelf.Alignment, gap: CGFloat) {
        let layer = SpaceBarOverlay.Item(
            layer: "L",
            glyph: .text("L", tinted: false)
        )
        let items =
            [layer]
            + (1...3).map {
                SpaceBarOverlay.Item(
                    space: SpaceID("\($0)"),
                    spaceGlyph: .text("\($0)", tinted: false),
                    apps: [],
                    active: $0 == 1,
                    overflow: 0,
                    focusInOverflow: false
                )
            }
        let need = SpaceBarOverlay.naturalLength(
            items: items,
            depth: depth,
            gap: gap
        )
        let lengths = SpaceBarOverlay.itemLengths(
            items,
            depth: depth,
            gap: gap
        )
        let total = SpaceBarOverlay.runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: 0
        )
        // The natural segment holds the whole run: nothing fades.
        #expect(total <= need)
        let start = SpaceBarOverlay.contentStart(
            total: total,
            axis: need,
            alignment: alignment,
            pad: SpaceBarItemView.pad
        )
        let plate = BarPlate.frame(
            strip: CGRect(x: 0, y: 0, width: need, height: depth),
            runStart: start,
            runTotal: total,
            inset: 0,
            gap: gap,
            horizontal: true,
            fit: .hug
        )
        let slack =
            alignment == .start ? need - plate.maxX : plate.minX
        #expect(slack >= 0)
        #expect(slack <= max(SpaceBarItemView.pad - gap, 0))
    }

    @Test(
        "the App run fills its natural segment",
        arguments: ShelfNeedParityTests.placements
    )
    func appRunFits(alignment: KiwiShelf.Alignment, gap: CGFloat) {
        var style = AppBarLook()
        style.itemGap = gap
        style.alignment = alignment
        let items = ["Mail", "A much longer window title", "Notes"]
            .enumerated().map {
                AppBarOverlay.Item(
                    id: WindowID(UInt32($0.offset + 1)),
                    text: $0.element,
                    icon: nil
                )
            }
        let need = AppBarOverlay.naturalLength(
            items: items,
            style: style,
            thickness: depth,
            capAxis: 2000
        )
        let strip = CGRect(x: 0, y: 0, width: need, height: depth)
        let metrics = AppBarOverlay().metrics(
            strip: strip,
            count: items.count,
            style: style,
            items: items,
            capAxis: 2000
        )
        #expect(metrics.inset == 0)
        let frames = AppBarOverlay.frames(
            lengths: Array(repeating: metrics.slot, count: items.count),
            in: strip,
            gap: gap,
            horizontal: true,
            alignment: alignment
        )
        let runStart = frames.first?.minX ?? 0
        let plate = BarPlate.frame(
            strip: strip,
            runStart: runStart,
            runTotal: metrics.total,
            inset: 0,
            gap: gap,
            horizontal: true,
            fit: .hug
        )
        let slack =
            alignment == .start ? need - plate.maxX : plate.minX
        #expect(slack == 0)
    }
}

/// The hard floor reaches the live plan (#1517): a minimum below
/// it, beside an App Bar that needs the whole edge, still leaves
/// the active Space item and a fade each side in view.
@MainActor
@Suite("Shelf floor wiring")
struct ShelfFloorWiringTests {
    @Test("the live plan keeps the Space section at its hard floor")
    func planHonoursTheFloor() throws {
        let core = makeTestCore()
        var settings = core.tiler.settings
        settings.kiwishelf.minimum = KiwiShelf.minimumRange.lowerBound
        let depth = settings.kiwishelf.thickness
        let spaces = (1...12).map {
            SpaceBarOverlay.Item(
                space: SpaceID("\($0)"),
                spaceGlyph: .text("Space \($0)", tinted: false),
                apps: [],
                active: $0 == 12,
                overflow: 0,
                focusInOverflow: false
            )
        }
        let windows = (1...40).map {
            AppBarOverlay.Item(
                id: WindowID(UInt32($0)),
                text: "A long window title \($0)",
                icon: nil
            )
        }
        let app = KiwiCore.AppBarContent(
            space: Space(id: "s", windows: []),
            style: settings.appBarLook(for: settings.monocle.appBar),
            groups: windows.map { [$0.id] },
            items: windows
        )
        let plan = core.shelfPlan(
            visible: CGRect(x: 0, y: 0, width: 600, height: 400),
            settings: settings,
            spaceItems: spaces,
            app: app
        )
        let slot = try #require(plan.arrangement.space)
        let floor = ShelfArrangement.hardFloor(
            activeExtent: SpaceBarOverlay.activeExtent(
                items: spaces,
                depth: depth,
                gap: settings.kiwishelf.itemGap
            ),
            thickness: depth,
            gap: settings.kiwishelf.itemGap
        )
        let plainMinimum =
            (600 - settings.kiwishelf.itemGap)
            * KiwiShelf.minimumRange.lowerBound / 100
        // The fixture only proves the wiring if the floor is
        // what binds: above the plain percentage.
        #expect(floor > plainMinimum)
        #expect(slot.length >= floor - 0.5)
    }
}
