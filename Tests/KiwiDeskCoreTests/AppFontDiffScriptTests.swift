import Foundation
import Testing

@testable import KiwiDeskCore

/// `scripts/app-font-diff`'s verdict, driven through its font-free
/// `--model` mode (fontTools is not on the test runner).
///
/// The verdict lets a drop land on green with no human look, so a
/// wrong `look=false` is the failure that matters. The bar reaches
/// a ligature only through `AppFontGlyphMap.ligature(for:)` — an
/// exact name first, then the longest `*` prefix — and the script
/// re-implements that in Python. `resolutionMatchesTheMap` holds
/// the copy to the Swift one on every name the script probed, so
/// the two cannot drift apart; the other tests hold the verdict on
/// the shapes that would otherwise pass as additions.
@Suite("App font diff script")
struct AppFontDiffScriptTests {
    struct Side {
        var rows: [(String, [String])]
        var sigs: [String: String?]

        var json: [String: Any] {
            [
                "icons": rows.enumerated().map { index, row in
                    [row.0, 0xE000 + index, row.1] as [Any]
                },
                "sigs": sigs.mapValues { $0.map { $0 as Any } ?? NSNull() },
            ]
        }

        var map: AppFontGlyphMap {
            AppFontGlyphMap(
                rows.flatMap { row in
                    row.1.map { (name: $0, ligature: row.0) }
                }
            )
        }
    }

    struct Verdict {
        let look: Bool
        let redrawn: [[String?]]
        let named: [String]
        let resolved: [String: [String: String?]]

        func redraws(_ name: String) -> Bool {
            redrawn.contains { $0.first == name }
        }
    }

    private func run(
        _ old: Side,
        _ new: Side,
        probes: [String] = []
    ) throws -> Verdict {
        let model: [String: Any] = [
            "old": old.json, "new": new.json, "probes": probes,
        ]
        let file = testTemporaryDirectory.appendingPathComponent(
            "app-font-model-\(UUID().uuidString).json"
        )
        try JSONSerialization.data(withJSONObject: model)
            .write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let run = try runPythonScript(
            at: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/app-font-diff"),
            arguments: ["--model", file.path]
        )
        try #require(run.status == 0, "\(run.stderr)")
        let object = try #require(
            try JSONSerialization.jsonObject(
                with: Data(run.stdout.utf8)
            ) as? [String: Any]
        )
        let resolved = try #require(
            object["resolved"] as? [String: [String: Any]]
        )
        return Verdict(
            look: try #require(object["look"] as? Bool),
            redrawn: (object["redrawn"] as? [[Any]] ?? []).map {
                $0.map { $0 as? String }
            },
            named: (object["named"] as? [[Any]] ?? []).compactMap {
                $0.first as? String
            },
            resolved: resolved.mapValues {
                $0.mapValues { $0 as? String }
            }
        )
    }

    /// Old and new share these; each test adds what it changes.
    static let base = Side(
        rows: [
            (":adobe:", ["Adobe*"]),
            (":code:", ["Code*", "Visual Studio Code"]),
            (":finder:", ["Finder"]),
        ],
        sigs: [":adobe:": "A", ":code:": "C", ":finder:": "F"]
    )

    @Test("A drop that only adds glyphs needs no look")
    func additionsOnly() throws {
        var new = Self.base
        new.rows.append((":bloom:", ["Bloom"]))
        new.sigs[":bloom:"] = "B"
        let verdict = try run(Self.base, new)
        #expect(!verdict.look)
        #expect(verdict.named == ["Bloom"])
    }

    @Test("An exact name under an old prefix needs a look")
    func exactShadowsPrefix() throws {
        var new = Self.base
        new.rows.append((":photoshop:", ["Adobe Photoshop"]))
        new.sigs[":photoshop:"] = "P"
        let verdict = try run(Self.base, new)
        #expect(verdict.look)
        #expect(verdict.redraws("Adobe Photoshop"))
    }

    @Test("A longer prefix under an old one needs a look")
    func longerPrefixShadows() throws {
        var new = Self.base
        new.rows.append((":insiders:", ["Code - Insiders*"]))
        new.sigs[":insiders:"] = "I"
        let verdict = try run(Self.base, new)
        #expect(verdict.look)
        #expect(verdict.redraws("Code - Insiders"))
    }

    @Test("A changed outline, a lost shape and an unmapped app look")
    func drawnGlyphChanges() throws {
        var outline = Self.base
        outline.sigs[":finder:"] = "F2"
        #expect(try run(Self.base, outline).redraws("Finder"))

        var unshaped = Self.base
        unshaped.sigs[":finder:"] = .some(nil)
        #expect(try run(Self.base, unshaped).redraws("Finder"))

        var unmapped = Self.base
        unmapped.rows[2] = (":finder:", [])
        #expect(try run(Self.base, unmapped).redraws("Finder"))
    }

    @Test("A rename that keeps the outline needs no look")
    func renameKeepsTheGlyph() throws {
        var new = Self.base
        new.rows[2] = (":files:", ["Finder"])
        new.sigs = [":adobe:": "A", ":code:": "C", ":files:": "F"]
        #expect(try !run(Self.base, new).look)
    }

    @Test("The script resolves every name as AppFontGlyphMap does")
    func resolutionMatchesTheMap() throws {
        var new = Self.base
        new.rows.append((":photoshop:", ["Adobe Photoshop*"]))
        new.rows.append((":ps26:", ["Adobe Photoshop 2026"]))
        new.rows.append((":finder2:", ["Finder"]))
        new.sigs[":photoshop:"] = "P"
        new.sigs[":ps26:"] = "Q"
        new.sigs[":finder2:"] = "F"
        let probes = [
            "Adobe", "Adobe Photoshop 2025", "Adobe Photoshop 2026",
            "Code", "Code - OSS", "Visual Studio Code", "Finder",
            "Fin", "Unknown",
        ]
        let verdict = try run(Self.base, new, probes: probes)
        for (side, map) in [
            ("old", Self.base.map), ("new", new.map),
        ] {
            let resolved = try #require(verdict.resolved[side])
            #expect(resolved.count >= probes.count)
            for (name, ligature) in resolved {
                #expect(
                    ligature == map.ligature(for: name),
                    "\(side) resolves \(name) unlike AppFontGlyphMap"
                )
            }
        }
    }
}
