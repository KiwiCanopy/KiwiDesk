import Foundation
import Testing

/// The one scroll-wheel event tap stays one, scroll-only, off the
/// main actor and out of the test run (#1656, #1519).
///
/// What each clause keeps, because a behavioural suite over the
/// `FakeTap` sees none of it:
/// - ONE `tapCreate(`: a second tap, or a mask widened past
///   `.scrollWheel`, is where an Input Monitoring prompt would
///   come from (input-and-animation.md, measured 2026-09-28).
/// - the install runs inside `start`'s own `Thread`: every scroll
///   on the Mac waits on the callback, and a tap on the main run
///   loop stalls them behind a slow app's AX reply.
/// - ONE live factory, in `ScrollGestures`, pinned inert in both
///   `makeTestCore` twins — the #565 class: a suite that binds a
///   gesture would otherwise take a session-wide tap.
///
/// Residue: the mask clause reads the `CGEventMask(` line, so a
/// mask built on another line and passed in reads as missing
/// (fail-closed); and the thread clause pins where `install()` is
/// CALLED, not what thread `CFRunLoopRun` then serves.
@Suite("The scroll tap stays one, scroll-only and off-main")
struct ScrollTapSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]
    private static let tapFile = root.appendingPathComponent(
        "Sources/KiwiDeskCore/Events/ScrollGestureTap.swift"
    )

    private static func sites(
        of needle: String
    ) throws -> [MachineTouchSite] {
        try productionTrees.flatMap {
            try SourceScan.identifierSites(of: needle, under: $0)
        }
    }

    @Test("one event tap in the app, in the scroll tap's file")
    func oneTap() throws {
        let sites =
            try Self.sites(of: "tapCreate(")
            + Self.sites(of: "CGEventTapCreate(")
        #expect(sites.map(\.site).count == 1)
        #expect(
            sites.allSatisfy {
                $0.file.lastPathComponent == "ScrollGestureTap.swift"
            },
            .init(rawValue: sites.map(\.site).joined(separator: ", "))
        )
    }

    @Test("the tap's mask is the scroll wheel alone")
    func scrollOnlyMask() throws {
        let source = try SourceScan.strippedSource(at: Self.tapFile)
        let maskLines = source.split(separator: "\n")
            .filter { $0.contains("CGEventMask(") }
        #expect(maskLines.count == 1)
        let line = String(maskLines.first ?? "")
        #expect(line.contains("CGEventType.scrollWheel.rawValue"))
        #expect(line.components(separatedBy: "CGEventType.").count == 2)
        #expect(!line.contains("|"))
        #expect(source.contains("eventsOfInterest: mask"))
    }

    @Test("the tap installs on its own thread")
    func installsOffMain() throws {
        let body = try SourceScan.functionBody(
            of: "start",
            in: "ScrollGestureTap.swift",
            under: "Events"
        )
        let thread = try #require(body.range(of: "Thread {"))
        let call = try #require(body.range(of: "install()"))
        #expect(thread.lowerBound < call.lowerBound)
        let source = try SourceScan.strippedSource(at: Self.tapFile)
        // One call beside the declaration: a second call site
        // could install on whatever thread it runs on.
        #expect(source.components(separatedBy: "install()").count == 3)
    }

    @Test("one live factory, pinned inert in both makeTestCore twins")
    func liveFactoryPinned() throws {
        let live = try Self.sites(of: "ScrollGestureTap.live(")
        #expect(live.count == 1)
        #expect(
            live.first?.file.lastPathComponent == "ScrollGestures.swift"
        )
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let twin = Self.root.appendingPathComponent(
                "Tests/\(target)/TestCore.swift"
            )
            let source = try SourceScan.strippedSource(at: twin)
            #expect(
                source.contains("mouse.scroll.makeTap = { _ in nil }"),
                .init(rawValue: "\(target) misses the scroll tap pin")
            )
        }
    }
}
