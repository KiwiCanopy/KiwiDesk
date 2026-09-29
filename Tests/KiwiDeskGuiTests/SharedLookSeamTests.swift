import Foundation
import Testing

/// The shared look's seams (#1752), which no behavioural suite can
/// see: the ledger has one home, every stored profile read for use
/// resolves through `resolvedSettings(of:)` / `wearingSharedLook`,
/// the prepare precedes the #1530 settle, and every Save door
/// writes the checklist before its other writes.
@Suite("Shared look seams (#1752)")
struct SharedLookSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources")

    private func squashed(_ relative: String) throws -> String {
        let raw = try String(
            contentsOf: Self.root.appendingPathComponent(relative),
            encoding: .utf8
        )
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace).joined()
    }

    /// `KiwiCore+SharedLook` and its write half are the one home;
    /// the declaration is the only other mention.
    @Test("the ledger has one home")
    func ledgerHasOneHome() throws {
        var touching: [String: Int] = [:]
        let core = Self.root.appendingPathComponent("KiwiDeskCore")
        for file in try SourceScan.swiftSources(under: core) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let count =
                source.components(separatedBy: "sharedLookLedger").count
                - 1
            if count > 0 { touching[file.lastPathComponent] = count }
        }
        #expect(touching["KiwiCore.swift"] == 1)
        #expect(
            Set(touching.keys)
                == [
                    "KiwiCore+SharedLook.swift",
                    "KiwiCore+SharedLookWrite.swift",
                    "KiwiCore.swift",
                ],
            "the ledger is touched outside its home: \(touching)"
        )
    }

    /// Every settings a stored profile or a built-in runs with are
    /// resolved: the apply, the Standard's apply, the draft seed.
    @Test("the use-readers resolve")
    func useReadersResolve() throws {
        let apply = try squashed(
            "KiwiDeskCore/Profiles/KiwiCore+ProfileResolution.swift"
        )
        #expect(apply.contains("tiler.settings=resolvedSettings(of:profile)"))
        #expect(
            apply.contains(
                "tiler.settings=wearingSharedLook(composed.settings)"
            )
        )
        #expect(!apply.contains("tiler.settings=profile.settings"))
        #expect(!apply.contains("tiler.settings=composed.settings"))
        let seed = try squashed(
            "KiwiDeskCore/App/KiwiCore+GuiConfigSeed.swift"
        )
        #expect(seed.contains("config.settings=resolvedSettings(of:profile)"))
    }

    /// The prepare reads `gui.json` ahead of the settle, which may
    /// rewrite a profile file.
    @Test("the prepare precedes the settle")
    func prepareBeforeSettle() throws {
        let body = try squashed("KiwiDeskCore/App/KiwiCore+Config.swift")
        let prepare = try #require(body.range(of: "prepareSharedLook()"))
        let settle = try #require(body.range(of: "settleSharedSets()"))
        #expect(prepare.lowerBound < settle.lowerBound)
    }

    /// The checklist's writes come first in every Save door: a
    /// profile it unticks keeps the look from before the Save's
    /// edits, and they precede the Save's `gui.json` write.
    @Test("every Save door writes the checklist first")
    func checklistFirst() throws {
        let doors = [
            (
                "KiwiDesk/Settings/SettingsModel+Profiles.swift",
                "core.persistProfile("
            ),
            (
                "KiwiDesk/Settings/SettingsModel+ProfileOverrides.swift",
                "core.overwriteProfile("
            ),
            (
                "KiwiDesk/Settings/SettingsModel+Globals.swift",
                "core.guiConfigStore.save("
            ),
        ]
        for (file, write) in doors {
            let body = try squashed(file)
            let reach = try #require(
                body.range(of: "saveLookReach()"),
                "\(file) never writes the checklist"
            )
            let other = try #require(body.range(of: write), "\(file)")
            #expect(reach.lowerBound < other.lowerBound, "\(file)")
            // The rule half writes gui.json's shared base too.
            if let rules = body.range(of: "saveRuleReach()") {
                #expect(reach.lowerBound < rules.lowerBound, "\(file)")
            }
        }
        let stored = try squashed(
            "KiwiDesk/Settings/SettingsModel+ProfileOverrides.swift"
        )
        let overwrite = try #require(
            stored.range(of: "core.overwriteProfile(")
        )
        let commit = try #require(
            stored.range(of: "core.commitSharedLook(ofProfile:name)")
        )
        #expect(overwrite.lowerBound < commit.lowerBound)
    }
}
