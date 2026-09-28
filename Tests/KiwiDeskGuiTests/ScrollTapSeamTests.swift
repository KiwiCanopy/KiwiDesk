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
/// Residue: the thread clause pins where `install()` is CALLED —
/// inside the closure `start` hands its `Thread` — not what thread
/// `CFRunLoopRun` then serves; and the pin clause reads the twins'
/// text, not that `makeTestCore` reaches the line.
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
        // `tapCreate` without its `(` also catches `tapCreateForPid(`
        // and `tapCreateForPSN(`; `EventTapCreate` the C spelling.
        let sites =
            try Self.sites(of: "tapCreate")
            + Self.sites(of: "EventTapCreate")
        #expect(sites.count == 1)
        #expect(
            sites.allSatisfy {
                $0.file.lastPathComponent == "ScrollGestureTap.swift"
            },
            .init(rawValue: sites.map(\.site).joined(separator: ", "))
        )
    }

    @Test("the tap is created with the one mask constant")
    func maskIsTheConstant() throws {
        // The constant's VALUE is `ScrollSampleTests`' to pin.
        let source = try SourceScan.strippedSource(at: Self.tapFile)
        #expect(source.contains("eventsOfInterest: Self.mask"))
        #expect(source.components(separatedBy: "eventsOfInterest:").count == 2)
    }

    @Test("the tap installs inside its own thread's closure")
    func installsOffMain() throws {
        let body = try SourceScan.functionBody(
            of: "start",
            in: "ScrollGestureTap.swift",
            under: "Events"
        )
        let closure = try #require(Self.closure(after: "Thread {", in: body))
        #expect(closure.contains("install()"))
        let source = try SourceScan.strippedSource(at: Self.tapFile)
        // One call beside the declaration: a second call site
        // could install on whatever thread it runs on.
        #expect(source.components(separatedBy: "install()").count == 3)
    }

    /// The brace-balanced body that opens at `marker`'s `{`.
    private static func closure(
        after marker: String,
        in text: String
    ) -> String? {
        guard let start = text.range(of: marker) else { return nil }
        var depth = 0
        var index = text.index(before: start.upperBound)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(text[start.upperBound..<index])
                }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
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
