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
            // The record lives in the real defaults: both of its
            // closures are inert too.
            #expect(
                Self.count("readWritten: { nil }", in: text) == 1,
                "\(twin)'s host reads the real record"
            )
            #expect(
                Self.count("writeWritten: { _ in }", in: text) == 1,
                "\(twin)'s host writes the real record"
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
        let files = try SourceScan.swiftSources(under: sources)
        #expect(files.count > 100)  // the walk saw the tree
        for file in files {
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

    /// The register of the re-check's doors (#3550): the Shortcuts
    /// page opening, a Hyper key recorded, a Settings Save (and
    /// `saveGuiConfig` beneath it), a wake or unlock, and nowhere
    /// else. A door owing through `oweHyperRemap` directly is
    /// counted too, so it cannot sidestep the register. Both count
    /// the bare name, so a call through a reference counts too; the
    /// trade is that each declaration counts once.
    @Test("the remap re-check has its doors")
    func recheckDoors() throws {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("Sources")
        )
        #expect(files.count > 100)
        var callers: [String: Int] = [:]
        var owers: [String: Int] = [:]
        for file in files {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let name = file.lastPathComponent
            let hits = Self.count("recheckHyperKey", in: text)
            if hits > 0 { callers[name] = hits }
            let owes = Self.count("oweHyperRemap", in: text)
            if owes > 0 { owers[name] = owes }
        }
        #expect(
            owers == [
                // The declaration and the re-check's one call.
                "KiwiCore+HyperKey.swift": 2,
                // A changed key, the dedupe a reload relies on.
                "KiwiCore+AppWideLive.swift": 1,
            ],
            "\(owers)"
        )
        #expect(
            callers == [
                "KiwiCore+HyperKey.swift": 1,  // the declaration
                "KiwiCore+GuiConfig.swift": 1,
                "KiwiCore+Bootstrap.swift": 1,
                "SettingsModel+AppWide.swift": 1,
                "SettingsModel+SaveAction.swift": 1,
                "ShortcutsSection.swift": 1,
            ],
            "\(callers)"
        )
        let gui = try Self.source(
            "Sources/KiwiDeskCore/App/KiwiCore+GuiConfig.swift"
        )
        #expect(
            try Self.body(
                of: gui,
                from: "func saveGuiConfig(",
                to: "func recoverKeybindings()"
            ).contains("recheckHyperKey()")
        )
        let bootstrap = try Self.source(
            "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
        )
        #expect(
            try Self.body(
                of: bootstrap,
                from: "sleepWake.onReturn = {",
                to: "}"
            ).contains("recheckHyperKey()")
        )
        let section = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
        )
        #expect(
            try Self.body(
                of: section,
                from: ".onAppear {",
                to: "}"
            ).contains("recheckHyperKey()")
        )
        let card = try Self.source(
            "Sources/KiwiDesk/Settings/Components/Keybindings/"
                + "ModifierKeysCard.swift"
        )
        #expect(Self.count("model.recordHyperKey(", in: card) == 1)
        #expect(!card.contains("$0.hyperKey ="))
        let save = try Self.source(
            "Sources/KiwiDesk/Settings/SettingsModel+SaveAction.swift"
        )
        #expect(
            try Self.body(
                of: save,
                from: "func performPrimarySave()",
                to: "\n    }\n"
            ).contains("core.recheckHyperKey()")
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
