import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The overflow marks through a real core (#2235): a retile's run
/// draws its marks, read off `runCovers`, named for VoiceOver, and
/// handed to the shared hover peek as a list that names its apps.
/// `.enabled(if:)` because the run resolves the Space's screen.
@Suite(
    "Overflow mark wiring (#2235)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct OverflowMarkWiringTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-overflow-mark-\(UUID().uuidString)"
                )
        )
        // Pinned (tests.md, #531): whether the stack overflows is
        // what the suite reads.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        return core
    }

    /// Six windows in one stack Space, focus on window 2: the run
    /// shows windows 2 and 3, and 4…6 wait behind window 3.
    private func makeSpace(_ core: KiwiCore) -> SpaceID {
        for id in 1...6 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        _ = core.execute("set_min_window_size", args: [.number(300)])
        core.state.workspaces.focus(WindowID(2), in: space)
        core.retile(animated: false)
        return space
    }

    @Test("A retile draws a mark on the run's hiding end")
    func retileDrawsTheMark() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        let space = makeSpace(core)
        let specs = core.overflowMarkSpecs()
        let spec = try #require(specs.first)
        #expect(specs.count == 1)
        #expect(spec.mark.space == space)
        #expect(spec.mark.end == .bottom)
        #expect(spec.mark.anchor == WindowID(3))
        #expect(spec.mark.windows == [4, 5, 6].map { WindowID($0) })
        #expect(spec.name == "More windows below: 3")
        // The retile's tail synced the manager from that reading.
        #expect(core.overflowMarks.anchors == [WindowID(3)])
    }

    @Test("A run that hides nothing draws no mark")
    func noOverflowNoMark() {
        let core = makeCore()
        let space = makeSpace(core)
        _ = core.execute("set_min_window_size", args: [.number(100)])
        core.retile(animated: false)
        #expect(core.state.workspaces[space]?.mode == .stack)
        #expect(core.overflowMarkSpecs().isEmpty)
        #expect(core.overflowMarks.anchors.isEmpty)
    }

    @Test("The mark's peek is a list whose one app keeps its icon")
    func peekNamesItsApp() {
        let rows = [4, 5].map {
            BarWindowRow(
                window: WindowID($0),
                pid: 900_004,
                app: "App",
                title: "Window \($0)",
                icon: NSImage()
            )
        }
        let run = BarPeekSource.run(rows.map(\.window))
        #expect(run.isList)
        let iconed = BarPeekContent(
            rows: rows,
            checks: run.isList,
            icons: run.iconsEveryGroup
        )
        #expect(iconed.groups.first?.icon != nil)
        // A Space Bar list of one app keeps the mixed-only rule.
        let overflow = BarPeekSource.overflow(rows.map(\.window))
        let bare = BarPeekContent(
            rows: rows,
            checks: overflow.isList,
            icons: overflow.iconsEveryGroup
        )
        #expect(bare.groups.first?.icon == nil)
    }

    /// The test process's own pid carries an icon a fixture pid
    /// lacks; the window is only filed, never laid out, so no
    /// frame or attach reaches the process (tests.md, #2289).
    @Test("Core hands the run source's icon rule to the peek")
    func coreAsksForIcons() throws {
        let core = makeCore()
        let own = ProcessInfo.processInfo.processIdentifier
        let id = WindowID(7)
        core.state.apply(
            .windowCreated(ManagedWindow(id: id, pid: own, appName: "Me"))
        )
        try #require(BarIconCache.icon(pid: own) != nil)
        let run = try #require(core.barPeekContent(.run([id]), on: nil))
        #expect(run.groups.first?.icon != nil)
        let glyph = try #require(
            core.barPeekContent(.overflow([id]), on: nil)
        )
        #expect(glyph.groups.first?.icon == nil)
    }

    @Test("A left press on a mark leaves its peek to the click")
    func leftPressOnAMarkSpares() {
        let peek = BarPeek(menus: NotificationCenter())
        peek.schedule = { _, _ in }
        let view = OverflowMarkView()
        let source = BarPeekSource.run([WindowID(4)])
        peek.pointer(in: view, on: view, source: source, edge: .bottom)
        #expect(peek.pending != nil)
        peek.pressed(on: view, type: .leftMouseDown)
        #expect(peek.pending != nil)
        // Any other button closes it, as on a bar glyph.
        peek.pressed(on: view, type: .rightMouseDown)
        #expect(peek.pending == nil)
    }
}
