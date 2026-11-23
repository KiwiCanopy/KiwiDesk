import Foundation
import Testing

/// The total space→display resolve re-places every Space from the
/// pins, which reverts a `move_space_to_display`, so only a screen
/// change, a profile apply, a config or Settings apply, a screen
/// setup's claim, boot and the #634 reset may call it (#3578,
/// profiles.md ▸ "A hand move holds through a door that changes no
/// screen"). Every other door takes `resolveSpaceDisplays(of:)`.
///
/// Pinned by count per file, so a site added or removed reds on
/// arrival. The needle is `resolveSpaceDisplays(` not followed by
/// an `of:` label, so a `mainID:` spelling counts and the scoped
/// door's calls do not; the scoped door's own declaration
/// (`of spaces:`) counts in its file. Fails open for a total
/// resolve reached through a wrapper the needle does not spell,
/// which is review's.
@Suite("Total space resolve callers")
struct SpaceResolveCallerSeamTests {
    /// Every file that may spell the total resolve, declarations
    /// included.
    private let callers: [String: Int] = [
        "Profiles/KiwiCore+SpaceDisplays.swift": 2,
        "Profiles/KiwiCore+ProfileResolution.swift": 2,
        "Profiles/KiwiCore+MonitorChange.swift": 2,
        "Profiles/KiwiCore+MonitorSettle.swift": 1,
        "Profiles/KiwiCore+MonitorSetClaim.swift": 1,
        "Profiles/KiwiCore+HeldSpaceBoot.swift": 1,
        "App/KiwiCore+GuiConfig.swift": 1,
        "App/KiwiCore+Reset.swift": 1,
        "App/KiwiCore+PlaceholderSpace.swift": 1,
    ]

    private static let total = try! NSRegularExpression(
        pattern: #"resolveSpaceDisplays\((?!\s*of\s*:)"#
    )

    private static func totals(in source: String) -> Int {
        Self.total.numberOfMatches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        )
    }

    private func counts() throws -> [String: Int] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let key = String(file.path.dropFirst(prefix.count))
            let hits = Self.totals(in: try SourceScan.strippedSource(at: file))
            if hits > 0 { counts[key] = hits }
        }
        return counts
    }

    @Test("The total resolve is reached from its ruled doors alone")
    func totalResolveHasRuledCallers() throws {
        let found = try counts()
        #expect(!found.isEmpty)
        for (file, count) in found.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) spells the total resolve \(count)× — a door "
                + "that changes no screen takes resolveSpaceDisplays"
                + "(of:); a ruled one owes profiles.md and an entry here"
            #expect(callers[file] == count, Comment(rawValue: unlisted))
        }
        for (file, expected) in callers {
            let vanished =
                "\(file) no longer spells the total resolve "
                + "\(expected)× — re-pin or drop its entry"
            #expect(found[file] == expected, Comment(rawValue: vanished))
        }
    }
}
