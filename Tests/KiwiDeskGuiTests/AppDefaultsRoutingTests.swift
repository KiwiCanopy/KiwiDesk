import Foundation
import Testing

/// Every KiwiDesk setting reads and writes `AppDefaults.store`
/// (#3121), so a test desk keeps its defaults in their own suite
/// and never writes the owner's domain. A direct
/// `UserDefaults.standard` is allowed only where the domain read
/// is not the app's own: the two reads of
/// `NSGlobalDomain`'s `_HIHideMenuBar`, and the tooltip delay
/// AppKit reads from the app's standard domain.
@Suite("Settings defaults go through AppDefaults (#3121)")
struct AppDefaultsRoutingTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File name → why it may name the standard domain.
    static let allowed: [String: String] = [
        "DisplayWatch.swift": "observes NSGlobalDomain's menu bar key",
        "GeometryUtils.swift": "reads NSGlobalDomain's menu bar key",
        "ToolTipDelay.swift": "AppKit reads the delay from .standard",
    ]

    /// The type spelled out, and the bare `.standard` handed as a
    /// defaults argument. Trade: a bare `.standard` in any other
    /// position (`?? .standard`, a `let x: UserDefaults =
    /// .standard`) is not seen, and `ShortcutBase.standard`, which
    /// shares the word, is never matched by these labels.
    static let needles = [
        "UserDefaults.standard", "UserDefaults = .standard",
        "(.standard)", "in: .standard", "defaults: .standard",
        "from: .standard", "to: .standard",
    ]

    @Test("no unlisted file names the standard defaults domain")
    func routed() throws {
        let trees = SourceScan.targetTrees(
            under: Self.root.appendingPathComponent("Sources")
        )
        #expect(trees.count >= 2, "both source targets are walked")
        var sites: [MachineTouchSite] = []
        for tree in trees {
            for needle in Self.needles {
                sites += try SourceScan.identifierSites(
                    of: needle,
                    under: tree
                )
            }
        }
        let stray = sites.filter {
            Self.allowed[$0.file.lastPathComponent] == nil
        }
        #expect(
            stray.isEmpty,
            .init(rawValue: stray.map(\.site).joined(separator: ", "))
        )
        // Every exemption still names the domain, so none outlives
        // its reason.
        let named = Set(sites.map(\.file.lastPathComponent))
        for file in Self.allowed.keys {
            #expect(named.contains(file), "\(file) names no .standard")
        }
    }
}
