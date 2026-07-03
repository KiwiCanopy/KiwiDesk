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
    @Test("Stash parks at the bottom-right, size unchanged")
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
            in: bounds
        )
        let peek = TilingEngine.stashPeek
        #expect(stashed.origin.x == bounds.maxX - peek)
        #expect(stashed.origin.y == bounds.maxY - peek)
        #expect(stashed.size == frame.size)
        // Only the peek corner overlaps the screen.
        let visible = stashed.intersection(bounds)
        #expect(visible.width == peek)
        #expect(visible.height == peek)
    }
}

@Suite("Native space profile binding", .serialized)
@MainActor
struct NativeSpaceBindingTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-core-\(UUID().uuidString)"
                )
        )
    }

    @Test("bind_profile_to_native_space records the binding")
    func bind() {
        let core = makeCore()
        core.execute(
            "save_profile",
            args: [.string("Coding")]
        )
        let response = core.execute(
            "bind_profile_to_native_space",
            args: [.number(2), .string("Coding")]
        )
        #expect(response.isSuccess)
        #expect(core.nativeSpaceBindings == [2: "Coding"])
    }

    @Test("CLI-style string arguments are accepted")
    func stringArgs() {
        let core = makeCore()
        let response = core.execute(
            "bind_profile_to_native_space",
            args: [.string("3"), .string("Studio")]
        )
        #expect(response.isSuccess)
        #expect(core.nativeSpaceBindings[3] == "Studio")
    }

    @Test("Rebinding a space replaces the previous profile")
    func rebind() {
        let core = makeCore()
        core.execute(
            "bind_profile_to_native_space",
            args: [.number(1), .string("Old")]
        )
        core.execute(
            "bind_profile_to_native_space",
            args: [.number(1), .string("New")]
        )
        #expect(core.nativeSpaceBindings == [1: "New"])
    }

    @Test("Desktops restore their last virtual space")
    func virtualSpaceMemory() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID(2))
        // Unknown desktop: default to the first space.
        #expect(core.virtualSpaceTarget(for: 3) == SpaceID(1))
        core.virtualSpaceMemory[3] = SpaceID(2)
        #expect(core.virtualSpaceTarget(for: 3) == SpaceID(2))
    }

    @Test("Invalid arguments fail")
    func invalidArgs() {
        let core = makeCore()
        #expect(
            !core.execute(
                "bind_profile_to_native_space",
                args: [.string("zero"), .string("x")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "bind_profile_to_native_space",
                args: [.number(0), .string("x")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "bind_profile_to_native_space",
                args: [.number(1)]
            ).isSuccess
        )
        #expect(core.nativeSpaceBindings.isEmpty)
    }
}
