import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A pointer reader on a split screen acts on the area under the
/// pointer (#3517): the pure point rule, the core's AX read, and
/// the drop's Cocoa cursor, side by side and stacked, with an
/// unsplit screen as the control.
@Suite("Area under the pointer")
@MainActor
struct AreaPointerTests {
    private let wide = Display(
        id: DisplayID(900_601),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private func core(_ axis: ScreenAreaCut.Axis?) throws -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.upsertDisplay(wide)
        if let axis {
            core.tiler.settings.displayAreas.store(
                try #require(
                    ScreenSplit.whole(width: 3440, height: 1440)
                        .splitting(0, axis)
                ),
                on: wide.fingerprint,
                order: core.liveScreenOrder
            )
        }
        let areas = core.state.workspaces.placements(of: wide.id)
        for (index, area) in areas.enumerated() {
            core.state.workspaces.assign(
                SpaceID("\(index + 1)"),
                to: area.id
            )
        }
        return core
    }

    /// An AX point `offset` into the screen's own points.
    private func ax(_ offset: CGPoint) -> CGPoint {
        let whole = GeometryUtils.flip(
            wide.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        return CGPoint(x: whole.minX + offset.x, y: whole.minY + offset.y)
    }

    @Test func pointRuleTakesTheHitElseTheNearest() {
        let left = PlacementID(display: wide.id, area: 0)
        let right = PlacementID(display: wide.id, area: 1)
        let rects = [
            (left, CGRect(x: 0, y: 0, width: 100, height: 100)),
            (right, CGRect(x: 100, y: 0, width: 100, height: 100)),
        ]
        #expect(
            KiwiCore.area(at: CGPoint(x: 150, y: 50), among: rects) == right
        )
        #expect(KiwiCore.area(at: CGPoint(x: 50, y: 50), among: rects) == left)
        #expect(
            KiwiCore.area(at: CGPoint(x: 260, y: -9), among: rects) == right
        )
    }

    @Test func unsplitScreenAnswersItsOneSpace() throws {
        let core = try core(nil)
        #expect(
            core.areaPlacement(
                atAX: ax(CGPoint(x: 3000, y: 1300)),
                on: wide.id
            ) == nil
        )
        #expect(
            core.shownSpace(atAX: ax(CGPoint(x: 3000, y: 1300)), on: wide.id)
                == "1"
        )
    }

    @Test func sideBySideAnswersTheAreaUnderThePoint() throws {
        let core = try core(.sideBySide)
        #expect(
            core.shownSpace(atAX: ax(CGPoint(x: 100, y: 700)), on: wide.id)
                == "1"
        )
        #expect(
            core.shownSpace(atAX: ax(CGPoint(x: 3000, y: 700)), on: wide.id)
                == "2"
        )
    }

    @Test func stackedAnswersTheAreaUnderThePoint() throws {
        let core = try core(.stacked)
        #expect(
            core.shownSpace(atAX: ax(CGPoint(x: 1000, y: 100)), on: wide.id)
                == "1"
        )
        #expect(
            core.shownSpace(atAX: ax(CGPoint(x: 1000, y: 1300)), on: wide.id)
                == "2"
        )
    }

    /// The drop's cursor is Cocoa; on a stacked split a y read as
    /// AX would land in the other area.
    @Test func dropReadsTheCocoaCursorOnAStackedSplit() throws {
        let core = try core(.stacked)
        core.dragCrossing.displayAt = { [wide] _ in wide.id }
        let lower = GeometryUtils.axPoint(ax(CGPoint(x: 1000, y: 1300)))
        core.drag.cursorLocation = { lower }
        #expect(core.dropDestination() == "2")
        let upper = GeometryUtils.axPoint(ax(CGPoint(x: 1000, y: 100)))
        core.drag.cursorLocation = { upper }
        #expect(core.dropDestination() == "1")
    }

    /// `get_state` names each Space's area and `list_monitors` each
    /// area's Space; an unsplit screen's Space has no area.
    @Test func queriesNameTheArea() throws {
        let core = try core(.sideBySide)
        let keys = core.state.workspaces.placements(of: wide.id)
            .map(\.key.description)
        guard case .object(let state) = core.stateJSON(),
            case .array(let spaces)? = state["spaces"]
        else {
            Issue.record("no spaces")
            return
        }
        let areaOf = Dictionary(
            uniqueKeysWithValues: spaces.compactMap { space in
                guard case .object(let o) = space,
                    case .string(let id)? = o["id"]
                else { return nil as (String, JSONValue)? }
                return (id, o["area"] ?? .null)
            }
        )
        #expect(areaOf["1"] == .string(keys[0]))
        #expect(areaOf["2"] == .string(keys[1]))
        guard
            case .array(let areas) = core.areasJSON(
                of: wide,
                screen: core.screenNumber(of: wide.id)
            )
        else {
            Issue.record("no areas")
            return
        }
        let shown = areas.compactMap { area -> JSONValue? in
            guard case .object(let o) = area else { return nil }
            return o["space_id"]
        }
        #expect(shown == [.string("1"), .string("2")])
        let whole = try self.core(nil)
        guard case .object(let plain) = whole.stateJSON(),
            case .array(let one)? = plain["spaces"],
            case .object(let first)? = one.first
        else {
            Issue.record("no spaces")
            return
        }
        #expect(first["area"] == .null)
    }
}
