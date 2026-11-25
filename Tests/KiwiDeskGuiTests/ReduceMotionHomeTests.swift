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

    /// Where a host needle must sit: a function's body, the body a
    /// declaration opens, the END of that body (a write every
    /// presentation above it inherits), or the whole file.
    private enum Scope {
        case function(String)
        case declaration(String)
        case declarationTail(String)
        case file
    }

    /// Each panel host reads the home once at show and hands that
    /// one value to its order-out and to its views (#3252). Each
    /// needle is scoped to the body it describes, so a decoy
    /// elsewhere in the file cannot stand in for it.
    @Test("the GUI hosts read the home at show")
    func hostsAreWired() throws {
        let wired: [(String, String, Scope, String)] = [
            (
                "Jump", "JumpPanelController.swift", .file,
                "varreduceMotion:()->Bool={ReduceMotion.isOn}"
            ),
            (
                "Jump", "JumpPanelController.swift", .function("show"),
                "PanelPresence(reduceMotion:reduceMotion())"
            ),
            (
                "Jump", "JumpPanelController.swift", .function("show"),
                "width:width).environment(\\.kiwiDeskReduceMotion,"
                    + "presence.reduceMotion)"
            ),
            (
                "", "PanelEntrance.swift", .function("fadeOut"),
                "letdelay=reduceMotion?0:Self.leaveDuration"
            ),
            (
                "", "PanelEntrance.swift",
                .declaration("structPanelEntrance:"),
                "privatevarreduceMotion:Bool{presence.reduceMotion}"
            ),
            (
                "", "PanelEntrance.swift",
                .declaration("structPanelContentFade:"),
                "privatevarreduceMotion:Bool{presence.reduceMotion}"
            ),
            (
                "CuePlate", "CuePlateController.swift", .function("show"),
                "model.present(content,reduceMotion:ReduceMotion.isOn)"
            ),
            (
                "CuePlate", "CuePlateController.swift", .function("hide"),
                "letfade=model.reduceMotion?0:CuePlateModel.fade"
            ),
            (
                "CuePlate", "CuePlateModel.swift", .function("present"),
                "self.reduceMotion=reduceMotion"
            ),
            (
                "CuePlate", "CuePlateModel.swift",
                .declaration("structCuePlateView:"),
                "privatevarreduceMotion:Bool{model.reduceMotion}"
            ),
            (
                "CuePlate", "CuePlateModel.swift",
                .declaration("structCuePlateView:"),
                ".environment(\\.kiwiDeskReduceMotion,reduceMotion)"
            ),
            (
                "BootNotice", "BootNoticeController.swift",
                .function("showIfDue"),
                "model.reduceMotion=ReduceMotion.isOn"
            ),
            (
                "BootNotice", "BootNoticeController.swift",
                .function("hide"),
                "letfade=model.reduceMotion?0:BootNoticeModel.fade"
            ),
            (
                "BootNotice", "BootNoticeView.swift",
                .declaration("structBootNoticeView:"),
                "privatevarreduceMotion:Bool{model.reduceMotion}"
            ),
            (
                "", "AppDelegate+Onboarding.swift",
                .function("showOnboarding"),
                ".environment(\\.kiwiDeskReduceMotion,ReduceMotion.isOn)"
            ),
            (
                "Updates", "UpdateWindowChrome.swift",
                .declaration("staticfuncwindow<Root:View>("),
                "letroot=root.environment(\\.kiwiDeskReduceMotion,"
                    + "ReduceMotion.isOn)"
            ),
            (
                "Shortcuts", "KeySequenceHintController.swift",
                .function("draw"),
                ".environment(\\.kiwiDeskReduceMotion,ReduceMotion.isOn)"
            ),
            // The Settings window keeps macOS's setting, live, as the
            // outermost write so its sheets and alerts inherit it.
            (
                "Settings", "SettingsView.swift",
                .declarationTail("varbody:someView{"),
                ".environment(\\.kiwiDeskReduceMotion,reduceMotion)"
            ),
        ]
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        for (dir, file, scope, needle) in wired {
            let url = root.appendingPathComponent(dir)
                .appendingPathComponent(file)
            let whole = try SourceScan.strippedSource(at: url)
                .filter { !$0.isWhitespace }
            let body: String
            switch scope {
            case .file: body = whole
            case .function(let name):
                body = try SourceScan.functionBody(
                    of: name,
                    in: file,
                    under: dir,
                    root: "Sources/KiwiDesk"
                ).filter { !$0.isWhitespace }
            case .declaration(let head), .declarationTail(let head):
                body =
                    SourceScan.declarationBody(after: head, in: whole)
                    ?? ""
            }
            #expect(!body.isEmpty, "\(file): \(scope)")
            if case .declarationTail = scope {
                #expect(body.hasSuffix(needle), "\(file): \(needle)")
            } else {
                #expect(body.contains(needle), "\(file): \(needle)")
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
