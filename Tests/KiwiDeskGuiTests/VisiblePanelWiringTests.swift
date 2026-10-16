import Foundation
import Testing

/// The visible-panel scan is wired in ONE door, which hands it
/// the event loop's button reader (#2344). The scan reads the
/// live WindowServer list and no fixture can drive it, so the
/// wiring is a needle: a caller spelling the scan beside the
/// door, or a door handing it `{ _ in false }`, is the #2344
/// defect back with `VisiblePanelButtonTests` green.
@Suite("Visible-panel scan wiring")
struct VisiblePanelWiringTests {
    private static let scan = "hasVisibleIgnoredPanel("
    private static let door = "showsIgnoredPanel("

    /// Every Swift file under `Sources/KiwiDeskCore`, stripped.
    private static func coreSources() throws -> [String: String] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let walker = try #require(
            FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil
            )
        )
        var sources: [String: String] = [:]
        for case let url as URL in walker
        where url.pathExtension == "swift" {
            sources[url.lastPathComponent] =
                try SourceScan.strippedSource(at: url)
        }
        return sources
    }

    private static func count(_ needle: String, in source: String)
        -> Int
    {
        source.components(separatedBy: needle).count - 1
    }

    @Test("the scan is called from the door alone")
    func scanHasOneCaller() throws {
        let sources = try Self.coreSources()
        #expect(sources.count >= 100, "scanned \(sources.count)")
        let spelled = sources.filter {
            Self.count(Self.scan, in: $0.value) > 0
        }
        #expect(
            Set(spelled.keys) == [
                // The declaration.
                "FloatDetection+Ignore.swift",
                // The door.
                "EventLoop+PanelButton.swift",
            ],
            "spelled in \(spelled.keys.sorted())"
        )
        #expect(
            Self.count(
                Self.scan,
                in: sources["EventLoop+PanelButton.swift"] ?? ""
            ) == 1
        )
    }

    @Test("the door hands the scan the button reader")
    func doorPassesTheReader() throws {
        let body = try SourceScan.functionBody(
            of: "showsIgnoredPanel",
            in: "EventLoop+PanelButton.swift",
            under: "Events"
        )
        try #require(!body.isEmpty)
        #expect(
            body.contains(
                "titlebarButton: untrackedTitlebarButton(of: pid)"
            )
        )
        #expect(body.contains("tracked: admittedWindows(of: pid)"))
        // The reader answers with the gate's own trait read, which
        // has no seam (`PanelButtonReaderTests` holds the rest).
        let reader = try SourceScan.functionBody(
            of: "untrackedTitlebarButton",
            in: "EventLoop+PanelButton.swift",
            under: "Events"
        )
        try #require(!reader.isEmpty)
        #expect(
            reader.components(
                separatedBy: "return Self.readsTitlebarButton(element"
            ).count - 1 == 2
        )
        let scan = try SourceScan.functionBody(
            of: "hasVisibleIgnoredPanel",
            in: "FloatDetection+Ignore.swift",
            under: "AX"
        )
        try #require(!scan.isEmpty)
        #expect(scan.contains("titlebarButton: titlebarButton"))
    }

    /// Both readers of the distrust ask the door: the boot and
    /// wake focus seed, and the focus-follow dwell.
    @Test("both callers take the door")
    func callersTakeTheDoor() throws {
        let sources = try Self.coreSources()
        for file in [
            "KiwiCore+FocusSeed.swift", "KiwiCore+SpaceCommands.swift",
        ] {
            #expect(
                Self.count(Self.door, in: sources[file] ?? "") == 1,
                "\(file) asks the door"
            )
        }
    }
}
