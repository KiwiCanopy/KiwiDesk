import Foundation
import Testing

@testable import KiwiDesk

/// Window management starts through one door that asks the
/// stored press (#2050, gui.md ▸ one door). A source scan, since
/// the door and its callers live in `AppDelegate`, which no test
/// constructs.
@Suite("Start Tiling wiring (#2050)")
struct StartTilingWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let gui = "Sources/KiwiDesk"

    private func source(_ file: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent("\(Self.gui)/\(file)")
        )
    }

    /// Every Swift file of the GUI tree, comments stripped.
    private func guiTree() throws -> [(name: String, text: String)] {
        let base = Self.root.appendingPathComponent(Self.gui)
        let walker = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: nil
        )
        var files: [(String, String)] = []
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            files.append(
                (
                    url.lastPathComponent,
                    try SourceScan.strippedSource(at: url)
                )
            )
        }
        #expect(!files.isEmpty)
        return files
    }

    private func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// The door refuses before it starts anything; a press, a
    /// grant and a launch all reach the core through it.
    @Test("the door asks the hold before starting the core")
    func doorIsGuarded() throws {
        let door = try #require(
            SourceScan.declarationBody(
                after: "func startManaging()",
                in: try source("AppDelegate+Permissions.swift")
            )
        )
        let guardAt = try #require(
            door.range(of: "guard coreHold == .running else {")
        )
        let start = try #require(door.range(of: "core.start()"))
        #expect(guardAt.lowerBound < start.lowerBound)
    }

    /// A second spelling of `core.start()` is a start path the
    /// door never sees.
    @Test("only the door starts the core")
    func onlyTheDoorStarts() throws {
        let starts = try guiTree().filter {
            $0.text.contains("core.start()")
        }
        #expect(starts.map(\.name) == ["AppDelegate+Permissions.swift"])
        #expect(count("core.start()", in: starts.first?.text ?? "") == 1)
    }

    /// The press records itself before reaching the door, or the
    /// door refuses the very press it exists for.
    @Test("Start Tiling records the press, then opens the door")
    func pressRecordsFirst() throws {
        let press = try #require(
            SourceScan.declarationBody(
                after: "func startTiling()",
                in: try source("AppDelegate+Permissions.swift")
            )
        )
        let mark = try #require(
            press.range(of: "TilingConsent.markStarted()")
        )
        let start = try #require(press.range(of: "startManaging()"))
        #expect(mark.lowerBound < start.lowerBound)
    }

    /// The launch seeds the store before anything reads it.
    @Test("the launch seeds the press before reading it")
    func launchSeedsFirst() throws {
        let launch = try #require(
            SourceScan.declarationBody(
                after: "func applicationDidFinishLaunching",
                in: try source("AppDelegate.swift")
            )
        )
        let seed = try #require(
            launch.range(of: "TilingConsent.seedAtLaunch(")
        )
        let sync = try #require(launch.range(of: "syncCoreHold()"))
        let start = try #require(launch.range(of: "startManaging()"))
        #expect(seed.lowerBound < sync.lowerBound)
        #expect(seed.lowerBound < start.lowerBound)
    }

    /// Each surface's press lands on the one door that records it.
    @Test("each Start Tiling reaches the recording door")
    func pressesReachTheDoor() throws {
        let delegate = try source("AppDelegate.swift")
        #expect(
            delegate.contains(
                "statusItem.onStartTiling = { [weak self] in\n"
                    + "            self?.startTiling()"
            )
        )
        #expect(
            delegate.contains(
                "created.setStartTiling { [weak self] in "
                    + "self?.startTiling() }"
            )
        )
        let hop = try #require(
            SourceScan.declarationBody(
                after: "func setStartTiling(",
                in: try source("Settings/SettingsWindowController.swift")
            )
        )
        #expect(hop.contains("model.onStartTiling = handler"))
        let tour = try source("AppDelegate+Onboarding.swift")
        #expect(
            tour.contains(
                "onboardingModel.onStartTiling = { [weak self] in\n"
                    + "            self?.startTiling()"
            )
        )
    }

    /// The not-started banner is a surfacing branch: deleting it
    /// leaves every other clause green.
    @Test("Settings draws the not-started banner")
    func settingsDrawsTheBanner() throws {
        let chrome = try source("Settings/SettingsView+Chrome.swift")
        #expect(
            chrome.contains(
                "case .notStarted:\n"
                    + "                TilingIdleBanner("
                    + "onStart: model.onStartTiling)"
            )
        )
    }

    /// Every surface takes its hold from the one sync, never a
    /// flag pushed past it.
    @Test("the surfaces are written from one reading")
    func oneReadingWritesTheSurfaces() throws {
        let tree = try guiTree().filter {
            $0.name != "AppDelegate+Permissions.swift"
        }
        for needle in [
            "setTilingIdle(", "setCoreHold(", ".hasStartedTiling =",
        ] {
            let writers = tree.filter { file in
                file.text.contains(needle)
                    && !file.text.contains("func \(needle)")
            }
            .map(\.name)
            #expect(
                writers.allSatisfy { $0 == "AppDelegate.swift" },
                "\(needle) written outside the sync: \(writers)"
            )
        }
    }
}
