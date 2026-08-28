import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The scrolling slot and the focused window's learned
/// app-enforced maximum (#1055, re-ruled by #1083).
///
/// The ceiling used to CLAMP an interactive grow and cue
/// `ownMaximum`. It no longer does: a learned bound is inferred
/// from timing, it is measurably wrong under load, and a guess
/// may not veto a press (`docs/design-decisions.md` owns the
/// ruling). A grow now travels past it, bounded by the viewport
/// and wordless there as it always was.
///
/// What survives unchanged is the property the ceiling was
/// protecting: one slot size serves the whole row, so the
/// ceiling must never REDUCE the shared slot — trimming a 900pt
/// slot to one window's 715pt maximum would visibly shrink
/// every neighbor. These tests still hold that, which is why
/// they were re-pointed rather than deleted; the domain's own
/// `ownMaximum` arm stays correct for a KNOWN limit and is
/// covered by `ScrollSlotDomainTests`. Split from
/// `ScrollingSlotCeilingTests` at the file
/// ceiling, and under the same screen trait for the same
/// reason: `resizeScrollingSlot` falls back to a 1920x1080
/// rect when no screen resolves, so headless these would
/// assert against a viewport the fixture never pinned — a
/// SKIP says that; a green would not.
///
/// Main-actor spend is light (tests.md): two windows and a
/// handful of `execute` calls per test.
@Suite(
    "Scrolling app-maximum ceiling (#1055)",
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ScrollingAppCeilingTests {
    /// A scrolling space on a pinned 1200pt-wide display
    /// (#531), focused on the first of two windows.
    private func makeCore() -> (core: KiwiCore, space: SpaceID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-app-ceiling-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        // Pin the default the exact expectations reason from
        // (#660): the `== 715` / `== 800` / `== 900` assertions
        // hold only while the global floor sits below them.
        #expect(core.tiler.settings.minWindowSize == 300)
        return (core, space)
    }

    /// The area the layout draws into — the viewport ceiling —
    /// read off the engine's own context (the sibling suite's
    /// helper, for the same reason: an assertion against it
    /// cannot be satisfied by a store that merely fits).
    private func areaExtent(_ core: KiwiCore) throws -> CGFloat {
        let input = try #require(
            core.tiler.layoutInput(state: core.state)
        )
        let context = input.context
        return context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        ).width
    }

    /// Teaches the learner a believed ceiling of 715pt for
    /// window 1 from the given asks — each observed twice from
    /// a settled read, the ladder's own confirmation shape.
    private func learnCeiling(
        _ core: KiwiCore,
        asks: [CGFloat]
    ) {
        for asked in asks {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(1),
                    size: CGSize(width: asked, height: 800)
                )
                core.tiler.boundLearner.observe(
                    WindowID(1),
                    currentSize: CGSize(width: 715, height: 800),
                    settledRead: true
                )
            }
        }
    }

    private func slotPoints(
        _ core: KiwiCore,
        _ space: SpaceID
    ) throws -> CGFloat {
        let live = try #require(core.state.workspaces[space])
        return core.tiler.settings.resolvedScrolling(for: live)
            .slotSize
            .editablePoints(along: 1200, horizontal: true)
    }

    @Test("A grow travels past the learned maximum, wordlessly")
    func growPassesTheLearnedMaximum() throws {
        // #1083: the seeded 715pt ceiling is present and
        // deliberately ignored. The press is neither truncated
        // at it nor cued against it — being wrong about a
        // learned limit must cost a window that does not fill
        // its region, never a press the user cannot make.
        let (core, space) = makeCore()
        learnCeiling(core, asks: [800, 900])
        core.execute(
            "scroll.set_slot_size",
            args: [.number(600)]
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(400)]
        )
        #expect(try slotPoints(core, space) > 715)
        #expect(refusals.isEmpty)
    }

    @Test("A grow below the maximum still grows, silently")
    func growBelowTheMaximumStillGrows() throws {
        let (core, space) = makeCore()
        learnCeiling(core, asks: [800, 900])
        core.execute(
            "scroll.set_slot_size",
            args: [.number(600)]
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(50)]
        )
        #expect(try slotPoints(core, space) == 650)
        #expect(refusals.isEmpty)
    }

    @Test("A viewport-truncated grow stays wordless")
    func viewportTruncationStaysSilent() throws {
        // The deliberate silence the writer's header rules:
        // with nothing learned, a grow the drawn area truncates
        // names no window and shows no pill.
        let (core, space) = makeCore()
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(4000)]
        )
        // The truncation the silence is ABOUT must have
        // happened — without this the test stays green if the
        // resize stops reaching the clamp at all
        // (code-reviewer, 2026-08-27).
        #expect(try slotPoints(core, space) == areaExtent(core))
        #expect(refusals.isEmpty)
    }

    @Test("A learned maximum past the viewport stays wordless")
    func maximumPastTheViewportStaysSilent() throws {
        // The cue's discrimination arm (guard-prover,
        // 2026-08-27): with a corroborated ceiling AT or ABOVE
        // the drawn area, the VIEWPORT is the binding limit, so
        // a truncated grow keeps the viewport's silence — the
        // `appMax < drawnAlong` clause, which no other fixture
        // can red because they stand the cue down on the nil
        // appMax alone.
        let (core, space) = makeCore()
        let area = try areaExtent(core)
        for asked in [area + 200, area + 300] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    WindowID(1),
                    size: CGSize(width: asked, height: 800)
                )
                core.tiler.boundLearner.observe(
                    WindowID(1),
                    currentSize: CGSize(
                        width: area + 100,
                        height: 800
                    ),
                    settledRead: true
                )
            }
        }
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(4000)]
        )
        #expect(try slotPoints(core, space) == area)
        #expect(refusals.isEmpty)
    }

    @Test("The ceiling never trims a resolved auto slot either")
    func ceilingNeverTrimsAnAutoSlot() throws {
        // The never-reduce floor's OWN weight (guard-prover,
        // 2026-08-27): for a `.points` store the configured
        // clause co-protects, so only an `auto` store — where
        // `configured` is 0 — can red the never-reduce floor. A
        // default auto slot resolves well above the learned
        // 715pt ceiling, and a grow press must not hand every
        // neighbor a trim to one window's maximum.
        let (core, space) = makeCore()
        learnCeiling(core, asks: [800, 1000])
        let before = try slotPoints(core, space)
        // The arm under test only exists while the resolved
        // slot sits ABOVE the ceiling.
        #expect(before > 715)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(50)]
        )
        // Never REDUCED to the ceiling — the property this
        // test has always existed for, and the half #1083 keeps.
        #expect(try slotPoints(core, space) >= before)
        // No cue: the ceiling is a guess and no longer speaks.
        #expect(refusals.isEmpty)
    }

    @Test("The ceiling never reduces the shared slot")
    func ceilingNeverReducesTheSharedSlot() throws {
        // One slot serves the whole row: trimming a 900pt slot
        // to one window's 715pt maximum would visibly shrink
        // every NEIGHBOR on a grow press.
        let (core, space) = makeCore()
        learnCeiling(core, asks: [800, 1000])
        core.execute(
            "scroll.set_slot_size",
            args: [.number(900)]
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(400)]
        )
        // The shared slot is never trimmed to one window's
        // maximum; it may grow, and it says nothing (#1083).
        #expect(try slotPoints(core, space) >= 900)
        #expect(refusals.isEmpty)
    }

    @Test("A single refused ask does not bind the write")
    func singleRefusalDoesNotBind() throws {
        // Corroboration gates the clamp end-to-end: one
        // believed entry (one ask, confirmed twice) is grid
        // noise as often as a ceiling, so the write must not
        // act on it.
        let (core, space) = makeCore()
        learnCeiling(core, asks: [800])
        core.execute(
            "scroll.set_slot_size",
            args: [.number(600)]
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(200)]
        )
        #expect(try slotPoints(core, space) == 800)
        #expect(refusals.isEmpty)
    }
}
