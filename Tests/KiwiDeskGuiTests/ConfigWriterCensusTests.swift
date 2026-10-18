import Foundation
import Testing

/// Every raw `.write(to:)` in Core is classified (#2325, #2324):
/// a write of a format-stamped config file refuses a file a newer
/// build wrote, through its store's door, and names the suite that
/// proves it; anything else says why it is no such file. A new
/// writer reds here until it is filed, so the sync slices' writers
/// cannot land beside the doors unread.
///
/// Counted per file, so a second writer in a filed file reds too.
/// Its reach is the `.write(to:` / `.write(toFile:` spelling: a
/// `FileManager` create, move or copy is outside it and review's.
@Suite("Config writer census (#2324)")
struct ConfigWriterCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → (writers, why each is safe).
    private static let allowed: [String: (Int, String)] = [
        "GuiConfigStore.swift": (
            1,
            "gui.json's door refuses a newer gui.json, machine.json "
                + "and bindings.json (NewerFormatLatchTests)"
        ),
        "ProfileManager.swift": (
            1,
            "the profile door refuses a newer profile "
                + "(NewerFormatWriteRefusalTests)"
        ),
        "MachineConfig.swift": (
            2,
            "a machine file's door, and the raw carry of undecodable "
                + "owed leaves, refuse a newer one "
                + "(MachineConfigTests, NewerFormatLatchTests)"
        ),
        "PaletteStore.swift": (
            2,
            "save, delete and rename decode first, which refuses a "
                + "newer library (NewerFormatLibraryWriteTests), and "
                + "a restore replaces after discarding the file; the "
                + "export writes a file the user picked"
        ),
        "LookStore.swift": (
            2,
            "save, delete and rename decode first, which refuses a "
                + "newer library (NewerFormatLibraryWriteTests), and "
                + "a restore replaces after discarding the file; the "
                + "export writes a file the user picked"
        ),
        "KiwiCore+AppWide.swift": (
            1,
            "the profile strip asks the predicate first "
                + "(NewerFormatWriteRefusalCallerTests)"
        ),
        "MigrationBackup.swift": (
            2,
            "rewrites only below the current format, and copies "
                + "into the machine folder's backups"
        ),
        "CorruptFile.swift": (
            1,
            "a corrupt file's copy into the machine folder's backups "
                + "(CorruptFilePolicyTests)"
        ),
        "KiwiCore+GuiConfig.swift": (
            1,
            "init.lua carries no format; the adoption refuses a "
                + "newer gui.json before it"
        ),
        "KiwiCore+ConfigTemplate.swift": (
            1,
            "a fresh init.lua template, which carries no format"
        ),
        "KiwiCore+Backup.swift": (
            1,
            "a backup bundle written where the user picked"
        ),
        "LogExport.swift": (1, "a log export the user picked"),
        "CrashRecovery.swift": (
            1,
            "this Mac's arrangement snapshot, no config file"
        ),
        "ServiceManager.swift": (1, "the LaunchAgent plist"),
    ]

    private static let writer = try! NSRegularExpression(
        pattern: #"\.write\(\s*to(File)?:"#
    )

    private static func writers(in text: String) -> Int {
        writer.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
    }

    private func coreCounts() throws -> [String: Int] {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore"
            )
        )
        #expect(!files.isEmpty)
        var counts: [String: Int] = [:]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let count = Self.writers(in: text)
            if count > 0 { counts[file.lastPathComponent] = count }
        }
        return counts
    }

    @Test("every raw writer in Core is filed, at its count")
    func everyWriterIsFiled() throws {
        let counts = try coreCounts()
        for (name, count) in counts {
            #expect(
                Self.allowed[name]?.0 == count,
                .init(rawValue: "\(name) has \(count) unfiled writer(s)")
            )
        }
        for name in Self.allowed.keys where counts[name] == nil {
            Issue.record("\(name) no longer writes; drop its entry")
        }
    }

    @Test("the matcher sees both spellings, across a line break")
    func matcherReaches() {
        #expect(Self.writers(in: "data.write(to: url)") == 1)
        #expect(Self.writers(in: "s.write(\n    toFile: p)") == 1)
        #expect(Self.writers(in: "field.write(value, into: &r)") == 0)
    }
}
