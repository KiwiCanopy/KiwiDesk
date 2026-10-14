import Foundation
import Testing

/// The Hyper key's `hidutil` host (#1870) rewrites the developer's
/// live key mapping and writes the real defaults, so every test
/// core runs on an inert one. A sibling of `MachineTouchTests`,
/// which is at the file ceiling: that suite holds the twins
/// identical, which a deletion from both passes.
@Suite("Hyper remap seam")
struct HyperRemapSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let pin =
        "core.hyperRemapHost = HyperKeyRemap.Host("
    private static let wiring =
        "var hyperRemapHost = HyperKeyRemap.Host.live"

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }

    private static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    @Test("both makeTestCore twins pin the host inert")
    func twinsPinTheHost() throws {
        for twin in [
            "Tests/KiwiDeskCoreTests/TestCore.swift",
            "Tests/KiwiDeskGuiTests/TestCore.swift",
        ] {
            let text = try Self.source(twin)
            #expect(
                Self.count(Self.pin, in: text) == 1,
                "\(twin) leaves the live hidutil host in place"
            )
            #expect(
                Self.count("run: { _ in nil }", in: text) == 1,
                "\(twin)'s host runs hidutil"
            )
        }
    }

    @Test("the live host has one home and one wiring")
    func liveHostHasOneHome() throws {
        let core = try Self.source(
            "Sources/KiwiDeskCore/App/KiwiCore.swift"
        )
        #expect(Self.count(Self.wiring, in: core) == 1)
        let remap = try Self.source(
            "Sources/KiwiDeskCore/OS/HyperKeyRemap.swift"
        )
        #expect(Self.count("/usr/bin/hidutil", in: remap) == 1)
        let sources = Self.root.appendingPathComponent("Sources")
        for file in try SourceScan.swiftSources(under: sources) {
            let name = file.lastPathComponent
            guard name != "HyperKeyRemap.swift" else { continue }
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(
                !text.contains("/usr/bin/hidutil"),
                "\(name) spawns hidutil outside the seam"
            )
        }
    }

    /// The remap is applied at `start()` and cleared at `stop()`;
    /// the behaviour suites call the doors directly, so the
    /// lifecycle wiring is read here.
    @Test("start applies and stop retires the remap")
    func lifecycleIsWired() throws {
        let boot = try Self.source(
            "Sources/KiwiDeskCore/App/KiwiCore+Boot.swift"
        )
        #expect(
            try Self.body(
                of: boot,
                from: "public func start()",
                to: "driveBootScan()"
            ).contains("applyHyperKey()")
        )
        let life = try Self.source(
            "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        #expect(
            try Self.body(
                of: life,
                from: "public func stop()",
                to: "gatherWindows()"
            ).contains("retireHyperKey()")
        )
    }

    /// The text between two needles, the second after the first.
    private static func body(
        of text: String,
        from first: String,
        to last: String
    ) throws -> Substring {
        let open = try #require(text.range(of: first))
        let tail = open.upperBound..<text.endIndex
        let close = try #require(text.range(of: last, range: tail))
        return text[open.upperBound..<close.lowerBound]
    }

    @Test("Carbon registers the mask without the hyper bit")
    func carbonTakesTheMask() throws {
        let carbon = try Self.source(
            "Sources/KiwiDeskCore/OS/CarbonHotkey.swift"
        )
        #expect(Self.count("modifiers.carbonMask,", in: carbon) == 1)
        #expect(Self.count("modifiers.rawValue,", in: carbon) == 0)
    }
}
