import Foundation
import Testing

/// Every Core write of a synced file — `gui.json` or a profile —
/// is ruled for the door a synced change enters by (#2324 slice
/// 3): a machine event stands down while `sync.adopting` is raised
/// (`SyncDoorTests` drives each), and anything else says why it
/// never answers another Mac's change. A new writer reds here until
/// it is ruled, so the door's promise is a census rather than a
/// sentence.
///
/// Counted per file over the store doors' spellings; a raw write
/// is `ConfigWriterCensusTests`' and a palette or look write is
/// the user's own act in Settings.
@Suite("Synced-file writer census (#2324)")
struct SyncWriterCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private enum Rule {
        /// The user's own act in Settings, a verb or a menu row.
        case userAct
        /// A one-shot crossing that ends once its file landed.
        case crossing
        /// Writes only where the file is missing.
        case seedWhenAbsent
        /// A machine event; stands down inside the door.
        case standsDown
    }

    /// File → (writes, rule).
    private static let ruled: [String: (Int, Rule)] = [
        "KiwiCore+GuiConfig.swift": (2, .userAct),
        "KiwiCore+BackupRestore.swift": (3, .userAct),
        "KiwiCore+LiveProfileWrite.swift": (1, .userAct),
        "KiwiCore+LookReach.swift": (1, .userAct),
        "KiwiCore+SharedLookWrite.swift": (2, .userAct),
        "KiwiCore+KeepLayouts.swift": (1, .userAct),
        "KiwiCore+MonitorSetClaim.swift": (1, .userAct),
        "KiwiCore+ProfileEdit.swift": (2, .userAct),
        "KiwiCore+ProfileSpaces.swift": (1, .userAct),
        "KiwiCore+RuleReachSave.swift": (2, .userAct),
        "KiwiCore+AppWide.swift": (1, .crossing),
        "KiwiCore+SharedLook.swift": (2, .crossing),
        "KiwiCore+Config.swift": (1, .seedWhenAbsent),
        "KiwiCore+GuiSpaces.swift": (1, .standsDown),
        "KiwiCore+ShortcutTopUp.swift": (3, .standsDown),
        "KiwiCore+SpaceShortcutDrop.swift": (2, .standsDown),
    ]

    private static let writer = try! NSRegularExpression(
        pattern: #"guiConfigStore\.save\(|\.saveIncludingBindings\("#
            + #"|profiles\.write\(|profiles\.save\("#
    )

    private func counts() throws -> [String: Int] {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("Sources/KiwiDeskCore")
        )
        #expect(!files.isEmpty)
        var counts: [String: Int] = [:]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let found = Self.writer.numberOfMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            )
            if found > 0 { counts[file.lastPathComponent] = found }
        }
        return counts
    }

    @Test("every synced-file writer in Core is ruled, at its count")
    func everyWriterIsRuled() throws {
        let counts = try counts()
        for (name, count) in counts {
            #expect(
                Self.ruled[name]?.0 == count,
                .init(rawValue: "\(name) has \(count) unruled write(s)")
            )
        }
        for name in Self.ruled.keys where counts[name] == nil {
            Issue.record("\(name) no longer writes; drop its entry")
        }
    }

    @Test("every writer ruled to stand down reads the door")
    func standDownsReadTheDoor() throws {
        let core = Self.root.appendingPathComponent("Sources/KiwiDeskCore")
        let files = try SourceScan.swiftSources(under: core)
        for (name, (_, rule)) in Self.ruled where rule == .standsDown {
            let file = try #require(
                files.first { $0.lastPathComponent == name }
            )
            let text = try SourceScan.strippedSource(at: file)
            #expect(
                text.contains("sync.adopting == 0"),
                .init(rawValue: "\(name) writes without the door's check")
            )
        }
    }
}
