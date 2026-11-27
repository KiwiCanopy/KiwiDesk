import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `get_state` names each Space's screen by the `list_monitors`
/// fingerprint, the one identifier every screen verb takes (#3628):
/// the field matches `list_monitors` by display id, and
/// `space.area or space.fingerprint` handed to `space_bar.set_edge`
/// writes the Space's own screen or area, where `display` read as a
/// position names another screen.
@Suite("Space screen in get_state (#3628)", .serialized)
@MainActor
struct SpaceScreenFingerprintTests {
    /// Display id 1 on purpose: a number set_edge reads as a
    /// position, and `right` is main, so position 1 is `right`.
    private static let left = Display(
        id: DisplayID(1),
        name: "Left",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
    )
    private static let right = Display(
        id: DisplayID(2),
        name: "Right",
        frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)
    )

    /// Space "a" on `left`, "b" on `right`, `right` the main screen.
    /// `makeTestCore` pins the main id, so a test restores it.
    private func twoScreens() -> KiwiCore {
        let core = makeTestCore()
        PositionalDisplays.mainIDOverride = { Self.right.id }
        core.state.apply(.displaysChanged([Self.left, Self.right]))
        core.state.workspaces.assign(SpaceID("a"), to: Self.left.id)
        core.state.workspaces.assign(SpaceID("b"), to: Self.right.id)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        core.tiler.settings = settings
        return core
    }

    /// Each Space object of `get_state`, by id.
    private func spaces(_ core: KiwiCore) -> [String: [String: JSONValue]] {
        guard case .object(let root)? = core.execute("get_state").data,
            case .array(let list)? = root["spaces"]
        else { return [:] }
        var byID: [String: [String: JSONValue]] = [:]
        for case .object(let space) in list {
            if case .string(let id)? = space["id"] { byID[id] = space }
        }
        return byID
    }

    /// The script idiom: the Space's area, else its fingerprint.
    private func screenArg(_ space: [String: JSONValue]?) -> JSONValue {
        let area = space?["area"] ?? .null
        return area == .null ? (space?["fingerprint"] ?? .null) : area
    }

    @Test("fingerprint is list_monitors' for the Space's display")
    func fingerprintMatchesListMonitors() throws {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = twoScreens()
        guard case .array(let monitors)? = core.listMonitors().data else {
            Issue.record("no monitors")
            return
        }
        var fingerprintOf: [Double: JSONValue] = [:]
        for case .object(let monitor) in monitors {
            if case .number(let id)? = monitor["id"] {
                fingerprintOf[id] = monitor["fingerprint"]
            }
        }
        let byID = spaces(core)
        for id in ["a", "b"] {
            let space = try #require(byID[id], Comment(rawValue: id))
            guard case .number(let display)? = space["display"] else {
                Issue.record("no display for \(id)")
                continue
            }
            #expect(space["fingerprint"] != .null, Comment(rawValue: id))
            #expect(
                space["fingerprint"] == fingerprintOf[display],
                Comment(rawValue: id)
            )
        }
        #expect(byID["a"]?["fingerprint"] == .string(Self.left.fingerprint))
    }

    /// Screens are connected, so a lookup that ignored the Space's
    /// own placement would leak one of theirs.
    @Test("a Space on no screen has a nil fingerprint")
    func unplacedSpaceHasNone() {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = twoScreens()
        core.state.workspaces.ensureSpace(SpaceID("loose"))
        let loose = spaces(core)["loose"]
        #expect(loose?["display"] == .null)
        #expect(loose?["fingerprint"] == .null)
    }

    /// The #3598 trap: `display` is 1, which set_edge reads as the
    /// main screen, `right`. The idiom writes `left` alone.
    @Test("area or fingerprint writes the Space's own screen")
    func roundTripWritesTheOwnScreen() throws {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = twoScreens()
        let space = try #require(spaces(core)["a"])
        #expect(space["display"] == .number(1))
        let set = core.execute(
            "space_bar.set_edge",
            args: [.string("bottom"), screenArg(space)]
        )
        #expect(set.isSuccess)
        #expect(
            core.tiler.settings.spaceBarStyle.edgeOverride
                == [Self.left.fingerprint: .bottom]
        )
    }

    /// On a split screen the idiom names the Space's own area, and
    /// a non-lead area's write leaves the lead area alone.
    @Test("a Space in a non-lead area writes that area alone")
    func splitWritesTheOwnArea() throws {
        let wide = Display(
            id: DisplayID(900_812),
            name: "Wide",
            frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
        )
        let core = makeTestCore()
        core.state.workspaces.upsertDisplay(wide)
        var settings = core.tiler.settings
        settings.displayAreas.store(
            try #require(
                ScreenSplit.whole(width: 3440, height: 1440)
                    .splitting(0, .sideBySide)
            ),
            on: wide.fingerprint,
            order: core.liveScreenOrder
        )
        settings.spaceBarStyle.setEdge(.top)
        core.tiler.settings = settings
        let areas = core.state.workspaces.placements(of: wide.id)
        try #require(areas.count == 2)
        core.state.workspaces.assign(SpaceID("1"), to: areas[0].id)
        core.state.workspaces.assign(SpaceID("2"), to: areas[1].id)
        let space = try #require(spaces(core)["2"])
        #expect(space["fingerprint"] == .string(wide.fingerprint))
        let key = areas[1].key.description
        #expect(screenArg(space) == .string(key))
        core.execute(
            "space_bar.set_edge",
            args: [.string("bottom"), screenArg(space)]
        )
        #expect(
            core.tiler.settings.spaceBarStyle.edgeOverride == [key: .bottom]
        )
    }
}
