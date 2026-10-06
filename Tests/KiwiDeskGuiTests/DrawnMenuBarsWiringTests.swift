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
                after: "static func visibleFrame(of screen: NSScreen)",
                in: text
            )
        )
        // RETURNED, not merely called: a dropped result is the
        // same bug with the needle still present.
        #expect(body.contains("return clearingMenuBar("))
        #expect(body.contains("DrawnMenuBars.bottom(of: screen)"))
        let ax = try #require(
            SourceScan.declarationBody(
                after: "public static func axVisibleFrame(",
                in: text
            )
        )
        #expect(ax.contains("visibleFrame(of: screen)"))
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
        // The observer registers itself, or it is created and
        // invalidated without ever hearing a change.
        let observer = try #require(
            SourceScan.declarationBody(
                after: "init(onChange: @escaping @MainActor @Sendable",
                in: watch
            )
        )
        #expect(observer.contains("addObserver("))
        #expect(observer.contains("forKeyPath: Self.key"))
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

    @Test("a pref change re-reads the bars and retiles, live-wired")
    func coreRemeasures() throws {
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
        // ASSIGNED to the seam, not merely named in the file.
        #expect(
            bootstrap.range(
                of: #"displayWatch\.readDrawnMenuBars\s*=\s*"#
                    + #"DisplayWatch\.liveMenuBars"#,
                options: .regularExpression
            ) != nil
        )
        let lifecycle = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        let schedule = try #require(
            SourceScan.declarationBody(
                after: "func scheduleMenuBarRemeasure(",
                in: lifecycle
            )
        )
        // No monitor changed: never a `.displaysChanged`.
        #expect(!schedule.contains("publishDisplays"))
        let changed = try #require(
            SourceScan.declarationBody(
                after: "if DrawnMenuBars.refresh(",
                in: schedule
            )
        )
        #expect(changed.contains("retile()"))
        // The retile's condition is the refresh's answer alone —
        // neither forced on nor off beside it.
        let head = try #require(
            schedule.range(of: "if DrawnMenuBars.refresh(")
        )
        let condition = schedule[head.lowerBound...]
            .prefix { $0 != "{" }
        for operand in ["||", "&&", "true", "false", "!"] {
            #expect(!condition.contains(operand))
        }
        let watch = try source(
            "Sources/KiwiDeskCore/Events/DisplayWatch.swift"
        )
        #expect(
            watch.contains(
                "var readDrawnMenuBars: () -> [CGRect] = { [] }"
            )
        )
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

    /// The #1868 seam under the correction: both twins memoize
    /// AppKit's read, and the door reads it only through the
    /// seam. A dropped memo reds nothing else — it only slows
    /// every run back down.
    @Test("both twins memoize AppKit's area under the correction")
    func twinsMemoizeTheAppKitRead() throws {
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let text = try source("Tests/\(target)/TestCore.swift")
            let memo = try #require(
                text.range(of: "GeometryUtils.appKitVisibleFrameOverride =")
                    .map { String(text[$0.upperBound...].prefix(400)) },
                .init(rawValue: "\(target) misses the memo")
            )
            // The closure caches: it reads and writes the memo.
            #expect(
                memo.contains("testAppKitFrames[key]"),
                .init(rawValue: "\(target)'s override does not memoize")
            )
            // The host's menu-bar setting is pinned too (#1894).
            #expect(
                text.contains(
                    "GeometryUtils.menuBarAutoHidesOverride = false"
                ),
                .init(rawValue: "\(target) reads the host's menu bar")
            )
        }
        let geometry = try source(
            "Sources/KiwiDeskCore/Tiling/GeometryUtils.swift"
        )
        let door = try #require(
            SourceScan.declarationBody(
                after: "static func visibleFrame(of screen: NSScreen)",
                in: geometry
            )
        )
        #expect(door.contains("appKitVisibleFrame(of: screen)"))
        #expect(!door.contains("screen.visibleFrame"))
        // And the AppKit door still consults the override.
        let appKit = try #require(
            SourceScan.declarationBody(
                after: "static func appKitVisibleFrame(of screen: NSScreen)",
                in: geometry
            )
        )
        #expect(appKit.contains("appKitVisibleFrameOverride(screen)"))
        // And the menu-bar reading consults its pin (#1894).
        let hides = try #require(
            SourceScan.declarationBody(
                after: "public static var menuBarAutoHides: Bool",
                in: geometry
            )
        )
        #expect(hides.contains("menuBarAutoHidesOverride"))
    }
}
