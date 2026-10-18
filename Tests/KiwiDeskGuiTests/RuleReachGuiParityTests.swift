import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Every rule-reach family reaches the Settings draft's own sites
/// (#453's review): `RuleReachFamilyParityTests` holds the Core
/// third, this the GUI's. The families are found by reflection over
/// `RuleReachSnapshot`, so a new one reds here until the encode,
/// the loaded page's resolve, the sidecar swap, the rule-half adopt
/// and drop, and the encode memo's key all name its draft field.
/// Each omission fails silently and differently: a stale memo, a
/// page showing the base, a profile's value baked into gui.json, a
/// failed write carrying the draft's half. Reach is a needle per
/// site; `LayoutCycleModelTests` and its siblings hold behaviour.
@Suite("Rule reach GUI parity")
@MainActor
struct RuleReachGuiParityTests {
    /// Each family → the `GuiConfig` field the draft edits it in.
    private static let draftField: [String: String] = [
        "appRules": "appRules",
        "floatRules": "floatRules",
        "keyLayers": "layers",
        "scrollGestures": "scrollGesture",
        "spaceHistory": "spaceHistory",
        "modeCycle": "modeCycle",
        "tileRules": "tileRules",
        "floatAutomatically": "floatAutomatically",
    ]

    /// Sites a family skips by design, with the reason.
    private static let skips: [String: Set<String>] = [
        // A stored page's shortcut diff is the tiling write's
        // (`adoptRuleHalf`'s own comment), never adopted here.
        "adoptRuleHalf": ["layers"]
    ]

    private func families() throws -> [String] {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        let snapshot = try #require(core.ruleReachSnapshot())
        return Mirror(reflecting: snapshot).children.compactMap {
            child in
            String(describing: type(of: child.value))
                .hasPrefix("RuleReachTable") ? child.label : nil
        }
    }

    private func source(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(file)
        return try SourceScan.strippedSource(at: url)
    }

    private func body(_ declaration: String, in file: String) throws
        -> String
    {
        let text = try source(file)
        let found = SourceScan.declarationBody(after: declaration, in: text)
        return try #require(found, "\(declaration) not found in \(file)")
    }

    @Test("every family is mapped, and found")
    func everyFamilyIsMapped() throws {
        let found = try families()
        #expect(found.count >= 6, "reflection found \(found)")
        #expect(Set(found) == Set(Self.draftField.keys))
    }

    @Test("each draft site names every family's field")
    func everySiteNamesEveryFamily() throws {
        let file = "SettingsModel+RuleReach.swift"
        let sites: [(String, String, (String) -> String)] = [
            ("encodeReach", "func encodeReach()", { "config.\($0)" }),
            (
                "resolveLoadedRules", "func resolveLoadedRules(",
                { "config.\($0) =" }
            ),
            ("sidecarConfig", "var sidecarConfig:", { "sidecar.\($0) =" }),
            (
                "adoptRuleHalf", "func adoptRuleHalf()",
                { "cleanConfig.\($0) = config.\($0)" }
            ),
            (
                "dropRuleHalf", "func dropRuleHalf()",
                { "config.\($0) = cleanConfig.\($0)" }
            ),
        ]
        let families = try families()
        #expect(!families.isEmpty)
        for (name, declaration, needle) in sites {
            let text = try body(declaration, in: file)
            for family in families {
                let field = try #require(Self.draftField[family])
                if Self.skips[name]?.contains(field) == true { continue }
                #expect(
                    text.contains(needle(field)),
                    "\(name) never names \(family) (\(needle(field)))"
                )
            }
        }
    }

    /// A row's ↺ settles a family's reach through this table (#792),
    /// so a family it misses leaves its reach behind.
    @Test("the revert's family table names every family's field")
    func revertTableNamesEveryFamily() throws {
        // The whole file: the table is an array literal, and the
        // file holds nothing else that names a draft field.
        let text = try source("RuleFamilyField.swift")
        let families = try families()
        #expect(!families.isEmpty)
        for family in families {
            let field = try #require(Self.draftField[family])
            #expect(
                text.contains("\\.\(field)")
                    || text.contains(".\(field) == $1.\(field)"),
                "RuleFamilyField never names \(family) (\(field))"
            )
        }
    }

    @Test("the encode memo keys on every family's field")
    func memoKeysEveryFamily() throws {
        let cache = try body(
            "struct EncodedReachCache",
            in: "SettingsModel+LayerPass.swift"
        )
        let text = try #require(
            SourceScan.declarationBody(
                after: "struct Key: Equatable",
                in: cache
            )
        )
        for family in try families() {
            let field = try #require(Self.draftField[family])
            #expect(
                text.contains("let \(field):"),
                "EncodedReachCache.Key misses \(family): a stale encode"
            )
        }
    }
}
