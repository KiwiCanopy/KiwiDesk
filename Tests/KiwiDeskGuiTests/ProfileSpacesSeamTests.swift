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
            "Profiles/KiwiCore+DesktopSpaces.swift": 5,
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

    /// The refused design, pinned NEGATIVELY: no map anywhere
    /// keys Space CONTENTS by a Desktop. #1230 refused that store
    /// because a window's Desktop is the WindowServer's fact and a
    /// copy of it can de-sync, losing or duplicating a window —
    /// and the cheap way back to it is a `[DesktopKey: …]` of
    /// window lists added beside the cursor.
    ///
    /// Located by the type pair rather than by a name, since the
    /// name is whatever its author picks.
    @Test("No map keys Space contents by Desktop")
    func noDesktopKeyedContentsStore() throws {
        let root = coreRoot
        var offenders: [String] = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for needle in [
                "[DesktopKey: [SpaceID: [WindowID]]]",
                "[DesktopKey: [WindowID]]",
                "[DesktopKey: Space]",
                "[DesktopKey: [SpaceID: Space]]",
                "[DesktopKey: WorkspaceManager]",
            ] where source.contains(needle) {
                offenders.append(
                    "\(file.lastPathComponent) declares "
                        + "\(needle)"
                )
            }
        }
        #expect(
            offenders.isEmpty,
            Comment(
                rawValue:
                    "a per-Desktop Space CONTENTS store is the "
                    + "design #1230 refused — the Desktop "
                    + "partition is emergent from window "
                    + "residence (KiwiCore+DesktopSpaces.swift "
                    + "carries the argument): "
                    + offenders.joined(separator: ", ")
            )
        )
    }
}
