import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Mission Control numbering")
struct NativeSpaceNumberingTests {
    private func space(
        _ id: UInt64,
        display: String = "A",
        isUser: Bool = true
    ) -> NativeSpace {
        NativeSpace(
            id: id,
            displayUUID: display,
            isCurrent: false,
            isUser: isUser
        )
    }

    @Test("Numbers user spaces 1-based across displays")
    func acrossDisplays() {
        let spaces = [
            space(10), space(11),
            space(20, display: "B"),
        ]
        #expect(NativeSpaces.number(of: 10, in: spaces) == 1)
        #expect(NativeSpaces.number(of: 11, in: spaces) == 2)
        #expect(NativeSpaces.number(of: 20, in: spaces) == 3)
    }

    @Test("Fullscreen spaces are not counted or numbered")
    func skipsFullscreen() {
        let spaces = [
            space(10),
            space(11, isUser: false),
            space(12),
        ]
        #expect(NativeSpaces.number(of: 12, in: spaces) == 2)
        #expect(NativeSpaces.number(of: 11, in: spaces) == nil)
    }

    @Test("Unknown space id yields nil")
    func unknownID() {
        #expect(
            NativeSpaces.number(of: 99, in: [space(1)]) == nil
        )
    }
}

@Suite("Inactive space stashing")
struct StashFrameTests {
    @Test("Stash parks bottom-right, asymmetric peek, size kept")
    func bottomRight() {
        let bounds = CGRect(
            x: 0,
            y: 25,
            width: 1920,
            height: 1055
        )
        let frame = CGRect(
            x: 100,
            y: 100,
            width: 800,
            height: 600
        )
        let stashed = TilingEngine.stashFrame(
            frame,
            in: bounds,
            corner: .bottomRight
        )
        let peekX = TilingEngine.stashPeekX
        let peekY = TilingEngine.stashPeekY
        #expect(stashed.origin.x == bounds.maxX - peekX)
        #expect(stashed.origin.y == bounds.maxY - peekY)
        #expect(stashed.size == frame.size)
        // Only the peek tab overlaps the screen: 1 pt wide,
        // floor-tall.
        let visible = stashed.intersection(bounds)
        #expect(visible.width == peekX)
        #expect(visible.height == peekY)
    }

    @Test("Bottom-left park anchors the window's right edge")
    func bottomLeft() {
        let bounds = CGRect(
            x: 0,
            y: 25,
            width: 1920,
            height: 1055
        )
        let frame = CGRect(
            x: 100,
            y: 100,
            width: 800,
            height: 600
        )
        let stashed = TilingEngine.stashFrame(
            frame,
            in: bounds,
            corner: .bottomLeft
        )
        // Right edge sits `peekX` past the left bound; the body
        // spills off the left.
        #expect(
            stashed.maxX == bounds.minX + TilingEngine.stashPeekX
        )
        #expect(stashed.origin.y == bounds.maxY - TilingEngine.stashPeekY)
        let visible = stashed.intersection(bounds)
        #expect(visible.width == TilingEngine.stashPeekX)
    }
}

/// Corner selection parks the wide overhang into dead space,
/// away from any adjacent display (#410).
@Suite("Stash corner selection")
struct StashCornerTests {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    @Test("A lone screen parks bottom-right")
    func loneScreen() {
        #expect(
            TilingEngine.optimalHideCorner(for: screen, among: [])
                == .bottomRight
        )
    }

    @Test("A right neighbor pushes the park to the left")
    func neighborRight() {
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 1000)
        #expect(
            TilingEngine.optimalHideCorner(
                for: screen,
                among: [right]
            ) == .bottomLeft
        )
    }

    @Test("A left neighbor keeps the park on the right")
    func neighborLeft() {
        let left = CGRect(x: -1000, y: 0, width: 1000, height: 1000)
        #expect(
            TilingEngine.optimalHideCorner(
                for: screen,
                among: [left]
            ) == .bottomRight
        )
    }

    @Test("Sandwiched between two screens defaults right")
    func sandwiched() {
        let left = CGRect(x: -1000, y: 0, width: 1000, height: 1000)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 1000)
        #expect(
            TilingEngine.optimalHideCorner(
                for: screen,
                among: [left, right]
            ) == .bottomRight
        )
    }

    @Test("A non-overlapping side screen is not a neighbor")
    func noVerticalOverlap() {
        // To the right on the x-axis but stacked far below —
        // the overhang can't reach it, so the right stays free.
        let below = CGRect(x: 1000, y: 5000, width: 1000, height: 1000)
        #expect(
            TilingEngine.optimalHideCorner(
                for: screen,
                among: [below]
            ) == .bottomRight
        )
    }
}

@Suite("Native space profile binding", .serialized)
@MainActor
struct DesktopBindingTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-core-\(UUID().uuidString)"
                )
        )
    }

    @Test("bind_profile_to_desktop records the binding")
    func bind() {
        let core = makeCore()
        core.execute(
            "save_profile",
            args: [.string("Coding")]
        )
        let response = core.execute(
            "bind_profile_to_desktop",
            args: [.number(2), .string("Coding")]
        )
        #expect(response.isSuccess)
        #expect(core.desktopBindings == [2: "Coding"])
    }

    @Test("CLI-style string arguments are accepted")
    func stringArgs() {
        let core = makeCore()
        let response = core.execute(
            "bind_profile_to_desktop",
            args: [.string("3"), .string("Studio")]
        )
        #expect(response.isSuccess)
        #expect(core.desktopBindings[3] == "Studio")
    }

    @Test("Rebinding a space replaces the previous profile")
    func rebind() {
        let core = makeCore()
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(1), .string("Old")]
        )
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(1), .string("New")]
        )
        #expect(core.desktopBindings == [1: "New"])
    }

    @Test("Desktops restore their last virtual space")
    func virtualSpaceMemory() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        // Unknown desktop: default to the first space.
        #expect(
            core.virtualSpaceTarget(for: .number(3)) == SpaceID(1)
        )
        core.desktopMemory.virtualSpaces[.number(3)] = SpaceID(2)
        #expect(
            core.virtualSpaceTarget(for: .number(3)) == SpaceID(2)
        )
    }

    @Test("Invalid arguments fail")
    func invalidArgs() {
        let core = makeCore()
        #expect(
            !core.execute(
                "bind_profile_to_desktop",
                args: [.string("zero"), .string("x")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "bind_profile_to_desktop",
                args: [.number(0), .string("x")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "bind_profile_to_desktop",
                args: [.number(1)]
            ).isSuccess
        )
        #expect(core.desktopBindings.isEmpty)
    }
}
