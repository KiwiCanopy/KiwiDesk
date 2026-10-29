import Foundation
import Testing

@testable import KiwiDeskCore

/// `get_settings` (#2782): the live keep document read back by the
/// pointers `keep_settings` takes, and one Space's resolved view.
@Suite("get_settings (#2782)", .serialized)
@MainActor
struct GetSettingsCommandTests {
    private let position = "/settings/layout/stack/stack_position"

    private func core() -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        _ = core.execute("stack.set_stack_position", args: [.string("right")])
        _ = core.execute(
            "stack.set_stack_position_override",
            args: [.string("2"), .string("left")]
        )
        return core
    }

    private func get(_ core: KiwiCore, _ args: [JSONValue]) -> JSONValue? {
        let response = core.execute(KiwiCore.getSettingsCommand, args: args)
        #expect(response.isSuccess, "\(args): \(response)")
        return response.data
    }

    @Test("no pointer answers the whole keep document")
    func wholeDocument() {
        let core = core()
        #expect(get(core, []) == core.keepDocument)
    }

    @Test("a pointer answers its leaf")
    func leaf() {
        let core = core()
        #expect(get(core, [.string(position)]) == .string("right"))
        #expect(
            get(core, [.string("/focus_wrap")])
                == .string(core.focusWrap.mode.rawValue)
        )
    }

    @Test("a raw override pointer answers the stored override")
    func rawOverride() {
        let core = core()
        let override = "/settings/layout/stack/override/2/stack_position"
        #expect(get(core, [.string(override)]) == .string("left"))
        let none = core.execute(
            KiwiCore.getSettingsCommand,
            args: [.string("/settings/layout/stack/override/1")]
        )
        #expect(!none.isSuccess)
    }

    @Test("a Space answers as that Space uses it")
    func resolvedSpace() {
        let core = core()
        #expect(
            get(core, [.string(position), .string("2")]) == .string("left")
        )
        #expect(
            get(core, [.string(position), .number(1)]) == .string("right")
        )
        let overrides = "/settings/layout/stack/override"
        let folded = core.execute(
            KiwiCore.getSettingsCommand,
            args: [.string(overrides), .string("2")]
        )
        #expect(!folded.isSuccess)
    }

    @Test("resolved(for:) folds each Space-wide override in")
    func resolvedFoldsOverrides() {
        var settings = TilingSettings()
        let space = SpaceID("2")
        settings.gapsOverride[space] = .uniform(7)
        settings.minWindowSizeOverride[space] = .square(123)
        settings.placementOverride[space] = .first
        var stack = StackOverride()
        stack.stackPosition = .left
        settings.stack.override[space] = stack
        let own = settings.resolved(for: space)
        #expect(own.gapsGlobal == .uniform(7))
        for layout in MinWindowSizes.Layout.allCases {
            #expect(own.minWindowSizes[layout] == .square(123))
        }
        #expect(own.stack.newWindowPlacement == .first)
        #expect(own.bsp.newWindowPlacement == .first)
        #expect(own.stack.stackPosition == .left)
        let other = settings.resolved(for: SpaceID("1"))
        #expect(other.gapsGlobal == settings.gapsGlobal)
        #expect(other.minWindowSizes == settings.minWindowSizes)
        #expect(other.stack.stackPosition == settings.stack.stackPosition)
    }

    @Test("a missing leaf, a non-pointer and an unknown Space refuse")
    func refusals() {
        let core = core()
        for args: [JSONValue] in [
            [.string("/settings/no_such_group")],
            [.string("settings/layout")],
            [.number(3)],
            [.string(position), .string("9")],
        ] {
            let response = core.execute(
                KiwiCore.getSettingsCommand,
                args: args
            )
            #expect(!response.isSuccess, "\(args)")
        }
    }
}
