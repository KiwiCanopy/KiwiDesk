import Foundation
import Testing

/// KiwiDesk's own Off joins macOS Reduce Motion in one read in Core
/// (#3238): `ReduceMotion.isOn`. A second AppKit read of the OS flag
/// there plays motion while the preset says Off, so that spelling
/// lives in `ReduceMotion.swift` alone. The GUI tree reads the same
/// home outside Settings (#3252): KiwiHub, the cue plates, the boot
/// notice and the tour take `\.kiwiDeskReduceMotion` or a value
/// their host read at show, and only the Settings window keeps
/// macOS's setting.
@Suite("Reduce Motion home (#3238)")
struct ReduceMotionHomeTests {
    private static let needle = "accessibilityDisplayShouldReduceMotion"
    private static let home = "ReduceMotion.swift"

    @Test("only the home reads the OS flag in Core")
    func oneRead() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var found: [String: Int] = [:]
        for tree in ["Sources/KiwiDeskCore"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty, "\(tree)")
            for file in files {
                let count = try SourceScan.strippedSource(at: file)
                    .occurrences(of: Self.needle)
                if count > 0 { found[file.lastPathComponent] = count }
            }
        }
        #expect(found == [Self.home: 1])
    }

    /// The trees ruled to stay on macOS's setting alone (#3252 ▸
    /// Ruling): the Settings window's motion is where Off is seen
    /// to take effect, and it is ordinary window chrome.
    private static let macOSOnly = ["Sources/KiwiDesk/Settings/"]

    /// Either OS read in the GUI tree — SwiftUI's environment value
    /// or AppKit's flag — plays motion under Off, so outside the
    /// ruled trees neither is spelled.
    @Test("the GUI reads KiwiDesk's Reduce Motion outside Settings")
    func guiReadsTheHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let tree = root.appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: tree)
        #expect(!files.isEmpty)
        let needles = [
            "accessibilityReduceMotion",
            Self.needle,
        ]
        var found: [String] = []
        var ruledHits = 0
        for file in files {
            let path = String(
                file.path.dropFirst(root.path.count + 1)
            )
            let source = try SourceScan.strippedSource(at: file)
            let hits = needles.reduce(0) {
                $0 + source.occurrences(of: $1)
            }
            guard hits > 0 else { continue }
            if Self.macOSOnly.contains(where: path.hasPrefix) {
                ruledHits += hits
            } else {
                found.append(path)
            }
        }
        #expect(found.isEmpty, "\(found)")
        // A ruled tree that stopped reading the OS is a stale entry.
        #expect(ruledHits > 0)
    }

    /// Each panel host reads the home once at show and hands that
    /// one value to its order-out and to its views (#3252).
    @Test("the GUI hosts read the home at show")
    func hostsAreWired() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let needles: [String: [String]] = [
            "Jump/JumpPanelController.swift": [
                "varreduceMotion:()->Bool={ReduceMotion.isOn}",
                "PanelPresence(reduceMotion:reduceMotion())",
                "width:width).environment(\\.kiwiDeskReduceMotion,"
                    + "presence.reduceMotion)",
            ],
            "PanelEntrance.swift": [
                "letdelay=reduceMotion?0:Self.leaveDuration",
                "privatevarreduceMotion:Bool{presence.reduceMotion}",
            ],
            "CuePlate/CuePlateController.swift": [
                "model.present(content,reduceMotion:ReduceMotion.isOn)",
                "letfade=model.reduceMotion?0:CuePlateModel.fade",
            ],
            "CuePlate/CuePlateModel.swift": [
                "self.reduceMotion=reduceMotion",
                "privatevarreduceMotion:Bool{model.reduceMotion}",
                ".environment(\\.kiwiDeskReduceMotion,reduceMotion)",
            ],
            "BootNotice/BootNoticeController.swift": [
                "model.reduceMotion=ReduceMotion.isOn",
                "letfade=model.reduceMotion?0:BootNoticeModel.fade",
            ],
            "BootNotice/BootNoticeView.swift": [
                "privatevarreduceMotion:Bool{model.reduceMotion}"
            ],
            "AppDelegate+Onboarding.swift": [
                ".environment(\\.kiwiDeskReduceMotion,ReduceMotion.isOn)"
            ],
        ]
        for (path, wanted) in needles {
            let source = try SourceScan.strippedSource(
                at: root.appendingPathComponent(path)
            ).filter { !$0.isWhitespace }
            for needle in wanted {
                #expect(source.contains(needle), "\(path): \(needle)")
            }
        }
    }

    /// A gate reading the home's OS half drops KiwiDesk's Off as
    /// surely as an `NSWorkspace` read, so no file in either tree
    /// names `ReduceMotion.system`; the home spells it bare.
    @Test("no gate reads the home's OS half")
    func noSystemHalf() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var found: [String] = []
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty, "\(tree)")
            for file in files
            where try SourceScan.strippedSource(at: file)
                .filter({ !$0.isWhitespace })
                .contains("ReduceMotion.system")
            {
                found.append(file.lastPathComponent)
            }
        }
        #expect(found.isEmpty, "\(found)")
    }

    /// The home joins both reads, so a gate asking it sees the
    /// preset's Off as well as macOS's.
    @Test("the home ORs KiwiDesk's Off into the OS read")
    func homeJoinsBoth() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let url = root.appendingPathComponent(
            "Sources/KiwiDeskCore/Animation/" + Self.home
        )
        let source = try SourceScan.strippedSource(at: url)
            .filter { !$0.isWhitespace }
        #expect(
            source.contains(
                "publicstaticvarisOn:Bool{"
                    + "joined(system:system,kiwiDesk:kiwiDesk)}"
            )
        )
    }

    /// The gates that once read the OS flag read the home now: the
    /// window engine, the bars' gate the overlays default to, and
    /// the flag's one writer, the live app-wide change.
    @Test("the gates and the flag's writer are wired")
    func gatesAreWired() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let needles = [
            "App/KiwiCore+Bootstrap.swift":
                "tiler.animation.reduceMotion={ReduceMotion.isOn}",
            "Bar/BarMotion.swift": "returnReduceMotion.isOn",
            "App/KiwiCore+AppWideLive.swift":
                "ReduceMotion.kiwiDesk=new.animationReduceMotion",
        ]
        for (path, needle) in needles {
            let source = try SourceScan.strippedSource(
                at: root.appendingPathComponent(path)
            ).filter { !$0.isWhitespace }
            #expect(source.contains(needle), "\(path)")
        }
    }
}
