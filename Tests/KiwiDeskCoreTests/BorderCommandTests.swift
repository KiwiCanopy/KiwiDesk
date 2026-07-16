import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

/// `border.*` command surface (#278): the clamp policy (silent
/// clamp on out-of-range width, `.fail` only on wrong type /
/// unknown enum) is a deliberate decision, pinned here.
@Suite("Border commands", .serialized)
@MainActor
struct BorderCommandTests {
    @Test("set_enabled and set_unfocused_enabled toggle")
    func toggles() {
        let core = makeCore()
        #expect(
            core.execute(
                "border.set_enabled",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.borderStyle.enabled)
        #expect(
            core.execute(
                "border.set_unfocused_enabled",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.tiler.settings.borderStyle.unfocusedEnabled)
    }

    @Test("set_width clamps out-of-range silently, rejects type")
    func widthClamp() {
        let core = makeCore()
        #expect(
            core.execute(
                "border.set_width",
                args: [.number(6)]
            ).isSuccess
        )
        #expect(core.tiler.settings.borderStyle.width == 6)
        // Above max → clamped, still success.
        #expect(
            core.execute(
                "border.set_width",
                args: [.number(999)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.borderStyle.width
                == BorderStyle.maxWidth
        )
        // Negative → clamped to min, still success.
        _ = core.execute("border.set_width", args: [.number(-4)])
        #expect(
            core.tiler.settings.borderStyle.width
                == BorderStyle.minWidth
        )
        // Wrong type → failure.
        #expect(
            !core.execute(
                "border.set_width",
                args: [.string("thick")]
            ).isSuccess
        )
    }

    @Test("set_corner_style parses the enum, rejects unknown")
    func cornerStyle() {
        let core = makeCore()
        #expect(
            core.execute(
                "border.set_corner_style",
                args: [.string("square")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.borderStyle.cornerStyle == .square
        )
        #expect(
            !core.execute(
                "border.set_corner_style",
                args: [.string("hexagon")]
            ).isSuccess
        )
    }

    @Test("set_focused_color validates hex")
    func colors() {
        let core = makeCore()
        #expect(
            core.execute(
                "border.set_focused_color",
                args: [.string("#FF0000")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.borderStyle.focusedColor
                == "#FF0000"
        )
        #expect(
            !core.execute(
                "border.set_focused_color",
                args: [.string("not-a-color")]
            ).isSuccess
        )
    }

    @Test("fit_gaps sizes the global gaps to the border")
    func fitGaps() {
        let core = makeCore()
        _ = core.execute("border.set_width", args: [.number(10)])
        #expect(
            core.execute("border.fit_gaps", args: []).isSuccess
        )
        // Rounded reach = width − 1 = 9.
        #expect(core.tiler.settings.gapsGlobal.outer.top == 9)
        #expect(
            core.tiler.settings.gapsGlobal.inner.horizontal == 9
        )
        // Unfocused on → inner gaps double.
        _ = core.execute(
            "border.set_unfocused_enabled",
            args: [.bool(true)]
        )
        _ = core.execute("border.fit_gaps", args: [])
        #expect(
            core.tiler.settings.gapsGlobal.inner.horizontal == 18
        )
        #expect(core.tiler.settings.gapsGlobal.outer.top == 9)
    }

    @Test("fit_gaps keeps an optional remaining gap (#295)")
    func fitGapsRemaining() {
        let core = makeCore()
        _ = core.execute("border.set_width", args: [.number(10)])
        // Rounded reach 9, +6 remaining on every edge and axis.
        #expect(
            core.execute(
                "border.fit_gaps",
                args: [.number(6)]
            ).isSuccess
        )
        #expect(core.tiler.settings.gapsGlobal.outer.top == 15)
        #expect(
            core.tiler.settings.gapsGlobal.inner.horizontal
                == 15
        )
        // Unfocused on: inner doubles the reach, then adds the
        // remaining once — 18 + 6.
        _ = core.execute(
            "border.set_unfocused_enabled",
            args: [.bool(true)]
        )
        _ = core.execute("border.fit_gaps", args: [.number(6)])
        #expect(
            core.tiler.settings.gapsGlobal.inner.horizontal
                == 24
        )
        #expect(core.tiler.settings.gapsGlobal.outer.top == 15)
        // A non-numeric argument fails; a negative one clamps
        // to the plain fit.
        #expect(
            !core.execute(
                "border.fit_gaps",
                args: [.string("wide")]
            ).isSuccess
        )
        _ = core.execute(
            "border.fit_gaps",
            args: [.number(-3)]
        )
        #expect(core.tiler.settings.gapsGlobal.outer.top == 9)
    }

    @Test("Unknown border setter fails")
    func unknown() {
        let core = makeCore()
        #expect(
            !core.execute(
                "border.set_bogus",
                args: [.bool(true)]
            ).isSuccess
        )
    }
}
