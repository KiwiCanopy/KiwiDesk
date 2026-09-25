import Foundation
import Testing

/// The #1386 wiring, which no fixture reaches: a test's screens
/// are the host's and the pref is the developer's own. Each
/// clause is one link of the chain pref → re-publish → refresh →
/// the one visible-frame derivation.
@Suite("Drawn menu bars wiring (#1386)")
struct DrawnMenuBarsWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
    }

    @Test("the visible frame clears the drawn bar when not hiding")
    func visibleFrameClears() throws {
        let text = try source(
            "Sources/KiwiDeskCore/Tiling/GeometryUtils.swift"
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "public static func axVisibleFrame(",
                in: text
            )
        )
        let orElse = try #require(
            SourceScan.declarationBody(after: "} else", in: body)
        )
        #expect(orElse.contains("clearingMenuBar("))
        #expect(orElse.contains("DrawnMenuBars.bottom(of: screen)"))
    }

    @Test("publishing the displays refreshes the drawn bars first")
    func publishRefreshes() throws {
        let text = try source(
            "Sources/KiwiDeskCore/Events/EventLoop+Apps.swift"
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func publishDisplays()",
                in: text
            )
        )
        let refresh = try #require(
            body.range(of: "DrawnMenuBars.refresh(")
        )
        #expect(body.contains("displayWatch.readDrawnMenuBars()"))
        let emit = try #require(body.range(of: ".displaysChanged("))
        #expect(refresh.lowerBound < emit.lowerBound)
    }

    @Test("both observations start and stop with the loop")
    func watchLifecycle() throws {
        let watch = try source(
            "Sources/KiwiDeskCore/Events/DisplayWatch.swift"
        )
        let start = try #require(
            SourceScan.declarationBody(after: "func start(", in: watch)
        )
        #expect(start.contains("didChangeScreenParametersNotification"))
        #expect(start.contains("MenuBarPrefObserver"))
        #expect(start.contains("self?.onMenuBarPrefChange()"))
        let stop = try #require(
            SourceScan.declarationBody(after: "func stop()", in: watch)
        )
        #expect(stop.contains("removeObserver(screenToken)"))
        #expect(stop.contains("prefObserver?.invalidate()"))
        let apps = try source(
            "Sources/KiwiDeskCore/Events/EventLoop+Apps.swift"
        )
        #expect(apps.contains("displayWatch.start"))
        let lifecycle = try source(
            "Sources/KiwiDeskCore/Events/EventLoop+Lifecycle.swift"
        )
        let loopStop = try #require(
            SourceScan.declarationBody(
                after: "public func stop()",
                in: lifecycle
            )
        )
        #expect(loopStop.contains("displayWatch.stop()"))
    }

    @Test("the core re-publishes on a pref change")
    func coreRepublishes() throws {
        let bootstrap = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
        )
        let wire = try #require(
            SourceScan.declarationBody(
                after: "eventLoop.displayWatch.onMenuBarPrefChange =",
                in: bootstrap
            )
        )
        #expect(wire.contains("scheduleMenuBarRemeasure()"))
        let lifecycle = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        let schedule = try #require(
            SourceScan.declarationBody(
                after: "func scheduleMenuBarRemeasure(",
                in: lifecycle
            )
        )
        #expect(schedule.contains("eventLoop.publishDisplays()"))
    }

    @Test("both makeTestCore twins pin the drawn-bar read")
    func twinsPinTheRead() throws {
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let text = try source("Tests/\(target)/TestCore.swift")
            #expect(
                text.contains(
                    "eventLoop.displayWatch.readDrawnMenuBars = { [] }"
                ),
                .init(rawValue: "\(target) misses the pin")
            )
        }
    }
}
