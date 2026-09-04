import Foundation
import Testing

@testable import KiwiDeskCore

/// #1230's two axes each have ONE door, and this pins that they
/// stay one door.
///
/// The doors answer different questions and are deliberately not
/// merged: `profilePartitioning` is a STORE (which Space a window
/// sat in under a given profile — KiwiDesk's own fact, which
/// nothing else records), while `virtualSpaces` is a one-`SpaceID`
/// cursor and the Desktop partition itself is never stored at all,
/// because a window's Desktop is the WindowServer's. A consumer
/// that reaches past either door re-derives a rule that has an
/// owner, which is how the two came to disagree before #1230.
///
/// Counts are pinned per file with comments stripped, the
/// `WorkspaceMapSealTests` shape. A new reader adds itself here
/// and says why.
@Suite("The #1230 Space doors stay one door each")
struct ProfileSpacesSeamTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Per needle: every file allowed to name it, by path under
    /// `Sources/KiwiDeskCore`, with today's exact count.
    private let allowed: [String: [String: Int]] = [
        // The profile axis. The three enders are the writes
        // outside the door: a re-key, a rename, a delete, plus
        // the #634 reset.
        "profilePartitioning": [
            "State/StateCoordinator.swift": 1,
            "Profiles/KiwiCore+ProfileSpaces.swift": 6,
            "App/KiwiCore+RekeyEvent.swift": 1,
            "App/KiwiCore+Reset.swift": 1,
            "Profiles/KiwiCore+ProfileRename.swift": 1,
            "Profiles/KiwiCore+Profiles.swift": 1,
        ],
        // The Desktop axis' cursor. `KiwiCore+AwayWindows` reads
        // it to file a boot-census window under the Space its
        // Desktop was showing (#1146) — the one reader outside
        // the door, and it reads rather than writes.
        // The door grew #1230's persistence pair, so the
        // sidecar's three sites — the load, the seed and the
        // write-time stamp — name it through here rather than
        // reaching the map themselves.
        "virtualSpaces": [
            "Profiles/DesktopMemory.swift": 1,
            "Profiles/KiwiCore+DesktopSpaces.swift": 9,
            "App/KiwiCore+AwayWindows.swift": 1,
        ],
    ]

    @Test("Each store is named only where its door lives")
    func storesStayBehindTheirDoors() throws {
        let root = coreRoot
        let prefix = root.path + "/"
        var counts: [String: [String: Int]] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            for needle in allowed.keys {
                let hits = source.occurrences(of: needle)
                guard hits > 0 else { continue }
                counts[needle, default: [:]][key] = hits
            }
        }
        for (needle, files) in counts {
            for (file, count) in files.sorted(
                by: { $0.key < $1.key }
            ) {
                let stray =
                    "\(file) names \(needle) \(count) time(s); "
                    + "go through the door "
                    + "(KiwiCore+ProfileSpaces for the profile "
                    + "axis, KiwiCore+DesktopSpaces for the "
                    + "Desktop one), or justify and pin it here"
                #expect(
                    allowed[needle]?[file] == count,
                    Comment(rawValue: stray)
                )
            }
        }
        // The inverse: a pinned count that vanished leaves an
        // unfalsifiable entry, and a mistyped root would pass
        // vacuously without it.
        for (needle, files) in allowed {
            for (file, expected) in files {
                let vanished =
                    "\(file) no longer names \(needle) "
                    + "\(expected) time(s) — drop or re-pin "
                    + "its entry"
                #expect(
                    counts[needle]?[file] == expected,
                    Comment(rawValue: vanished)
                )
            }
        }
    }

    /// The refused design, pinned NEGATIVELY: no stored map
    /// anywhere is keyed by `DesktopKey` except the two that are
    /// named here. #1230 refused a per-Desktop Space CONTENTS
    /// store because a window's Desktop is a fact KiwiDesk READS
    /// and does not own, so a copy read while the compositor is
    /// still mutating it can disagree — and every disagreement
    /// loses or duplicates a window.
    ///
    /// Located by the KEY rather than by the value's spelling.
    /// The first draft listed five literal type shapes, so a
    /// named wrapper — `[DesktopKey: DesktopWorkspaces]`, the
    /// likeliest thing anyone would actually write — sailed
    /// through green while the suite read as pinning the
    /// refusal. tests.md forbids exactly that in a negative
    /// clause: locate the subject by something it cannot lose,
    /// and a Desktop-keyed store cannot lose its key.
    @Test("Only the ruled maps are keyed by Desktop")
    func noDesktopKeyedContentsStore() throws {
        // Every `[DesktopKey: …]` declaration KiwiDesk may hold,
        // with what each one stores. A new entry is a new durable
        // per-Desktop record and owes the argument above.
        let allowed: [String: String] = [
            "Profiles/DesktopMemory.swift": "the Space CURSOR",
            "App/KiwiCore.swift": "the profile BINDINGS",
            "Config/GuiConfig.swift": "the cursor, persisted",
            "Config/GuiConfigStore.swift": "the write-time stamp",
            "Profiles/KiwiCore+DesktopBindings.swift":
                "the shared re-key, generic over the value",
            "Profiles/KiwiCore+DesktopSpaces.swift":
                "the cursor's door",
        ]
        let root = coreRoot
        let prefix = root.path + "/"
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = source.occurrences(of: "[DesktopKey:")
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            found[key] = hits
        }
        // Vacuity pin: a mistyped root would find nothing and
        // pass, which is the fail-open this clause exists to
        // avoid.
        #expect(found.count >= 4)
        for file in found.keys.sorted() {
            #expect(
                allowed[file] != nil,
                Comment(
                    rawValue:
                        "\(file) declares a Desktop-keyed map. "
                        + "If it stores Space CONTENTS it is the "
                        + "design #1230 refused "
                        + "(KiwiCore+DesktopSpaces.swift carries "
                        + "the argument); otherwise add it here "
                        + "and say what it stores."
                )
            )
        }
    }
}
