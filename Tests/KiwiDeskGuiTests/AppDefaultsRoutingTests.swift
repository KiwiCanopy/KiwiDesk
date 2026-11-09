import Foundation
import Testing

/// Every KiwiDesk setting reads and writes `AppDefaults.store`
/// (#3121), so a test desk keeps its defaults in their own suite
/// and never writes the owner's domain. The standard domain is
/// named only where the read is not a setting: another domain's
/// key, a key AppKit reads from the app's domain, or the record of
/// machine-wide state one instance at a time owns, which the
/// owner's instance must still find after a test desk.
@Suite("Settings defaults go through AppDefaults (#3121)")
struct AppDefaultsRoutingTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File name → why it may name the standard domain.
    static let allowed: [String: String] = [
        "DisplayWatch.swift": "observes NSGlobalDomain's menu bar key",
        "GeometryUtils.swift": "reads NSGlobalDomain's menu bar key",
        "ToolTipDelay.swift": "AppKit reads the delay from .standard",
        "HyperKeyRemap.swift": "records the hidutil remap it owns",
        "VisionAppearance.swift": "records the system appearance debt",
    ]

    /// `UserDefaults.standard`, a `UserDefaults = .standard`
    /// default, and a bare `.standard` after any argument label.
    /// Trade: the labels `base:` and `on:` are left out by name,
    /// since `ShortcutBase.standard` takes them, so a defaults
    /// parameter with either label is not seen; neither is a bare
    /// `.standard` after `??`, `=` or a ternary, the shapes
    /// `ShortcutBase` and the accessor itself use.
    private static let standard = try! NSRegularExpression(
        pattern: #"UserDefaults\.standard\b|UserDefaults\s*=\s*\.standard\b"#
            + #"|\b(?!base\b|on\b)\w+:\s*\.standard\b(?!\()"#
    )

    /// "File.swift:line" for every stripped source line `test` takes.
    private static func sites(
        matching test: (String) -> Bool
    ) throws -> [String] {
        let trees = SourceScan.targetTrees(
            under: Self.root.appendingPathComponent("Sources")
        )
        #expect(trees.count >= 2, "both source targets are walked")
        var found: [String] = []
        for tree in trees {
            for file in try SourceScan.swiftSources(under: tree) {
                let lines = try SourceScan.strippedSource(at: file)
                    .split(separator: "\n", omittingEmptySubsequences: false)
                for (index, line) in lines.enumerated()
                where test(String(line)) {
                    found.append("\(file.lastPathComponent):\(index + 1)")
                }
            }
        }
        return found
    }

    private static func file(of site: String) -> String {
        String(site.prefix { $0 != ":" })
    }

    @Test("no unlisted file names the standard defaults domain")
    func routed() throws {
        let sites = try Self.sites { line in
            Self.standard.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
            ) != nil
        }
        let stray = sites.filter { Self.allowed[Self.file(of: $0)] == nil }
        #expect(stray.isEmpty, .init(rawValue: stray.joined(separator: ", ")))
        // Every exemption still names the domain, so none outlives
        // its reason, and the scan reads real code.
        let named = Set(sites.map(Self.file(of:)))
        for file in Self.allowed.keys {
            #expect(named.contains(file), "\(file) names no .standard")
        }
    }

    @Test("an @AppStorage names AppDefaults.store")
    func appStorageRouted() throws {
        let sites = try Self.sites {
            $0.contains("@AppStorage(") && !$0.contains("AppDefaults.store")
        }
        #expect(sites.isEmpty, .init(rawValue: sites.joined(separator: ", ")))
    }

    @Test("only TestDesk spells KIWIDESK_HOME")
    func oneReadOfTheVariable() throws {
        let sites = try Self.sites { $0.contains("\"KIWIDESK_HOME\"") }
        #expect(sites.count == 1)
        #expect(sites.allSatisfy { Self.file(of: $0) == "TestDesk.swift" })
    }
}
