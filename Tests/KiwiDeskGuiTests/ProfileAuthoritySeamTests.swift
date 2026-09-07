import Foundation
import Testing

@testable import KiwiDeskCore

/// Who may move the live profile NAME, and who may write a
/// profile (#1249).
///
/// Split from `ProfileSpacesSeamTests` at the §2.1 ceiling along
/// its own seam: that suite pins where the #1230 STORES may be
/// named, this one pins the authority the profile store files
/// FOR — `ProfileManager.currentName`, which the store kept a
/// hand-mirror of until the pair shipped one defect three times.
/// The obligations are profiles.md ▸ "Whose arrangement is
/// live"; these are the clauses that hold them.
@Suite("The live profile name has one authority (#1249)")
struct ProfileAuthoritySeamTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// The profile WRITE has ONE home (#1249). `ProfileManager
    /// .save` makes its argument current, so the profile whose
    /// arrangement is on screen loses its name the moment it
    /// returns — the partitioning has to be filed FIRST, and a
    /// site that spells the write itself files nothing.
    ///
    /// `KiwiCore.saveProfile` is that home and the only place in
    /// Core allowed to name `profiles.save(`. Counting the
    /// EXITS was the weaker predecessor: it forced a fourth exit's
    /// author to come and look, but could not read whether the
    /// site did the pairing, and the third exit (`applyStandard`)
    /// shipped without it anyway (#1246). One home can be read.
    private let writeDoor =
        "Profiles/KiwiCore+ProfileSpaces.swift"

    @Test("The profile write has one home")
    func profileWriteGoesThroughOneDoor() throws {
        let root = coreRoot
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = source.occurrences(of: "profiles.save(")
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key] = hits
        }
        let stray =
            "profiles.save( is named outside the write door; go "
            + "through KiwiCore.saveProfile, which files the "
            + "outgoing partitioning before the name moves (#1249)"
        #expect(counts == [writeDoor: 1], Comment(rawValue: stray))
    }

    /// The two verbs that move the live profile name belong to
    /// the two apply doors, each at the end of its own body —
    /// whoever moves the name moves the Spaces with it (#1249,
    /// profiles.md ▸ "Whose arrangement is live").
    ///
    /// Scoped to the DOOR'S BODY rather than to its file, which
    /// is the trade this clause exists to make: both doors live
    /// in `KiwiCore+ProfileResolution.swift` beside
    /// `applyStandard` and `reapplyActiveProfileState`, so a
    /// file-count clause stays green when the call moves to a
    /// neighbour — satisfied or broken by a function that is not
    /// its subject. The cost of the narrowing is that it reads
    /// the declaration's exact spelling: a re-signature of either
    /// `apply` — or `swift format` joining a signature onto one
    /// line — reds this as "no such door" rather than as a stray
    /// call, so read the failure before assuming a violation. And
    /// it counts occurrences, so it cannot see WHERE in the body
    /// the verb sits; that `apply(profile:)`'s must be LAST is
    /// held behaviourally by `ProfilePartitioningTests`
    /// (`guard-prover`, 2026-09-07).
    private let applyDoors: [(door: String, verb: String)] = [
        (
            "func apply(\n        profile: Profile,",
            "profiles.becameLive("
        ),
        (
            "func apply(\n        composed:",
            "profiles.noProfileIsLive("
        ),
    ]

    @Test("Only the apply doors say which profile is live")
    func onlyTheApplyDoorsSayWhichProfileIsLive() throws {
        let root = coreRoot
        let file = root.appendingPathComponent(
            "Profiles/KiwiCore+ProfileResolution.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        for (door, verb) in applyDoors {
            let body = SourceScan.declarationBody(
                after: door,
                in: source
            )
            #expect(
                body != nil,
                Comment(
                    rawValue:
                        "cannot find the body of '\(door)' — if "
                        + "the door was re-signed, re-pin it here"
                )
            )
            #expect(
                (body?.occurrences(of: verb) ?? 0) == 1,
                Comment(
                    rawValue:
                        "\(verb) is not spelled exactly once in "
                        + "the body of '\(door)' (#1249)"
                )
            )
        }
        // And nowhere else in Core, so the pairing cannot be
        // moved to a neighbour that changes no Spaces.
        let prefix = root.path + "/"
        var strays: [String: Int] = [:]
        for candidate in try SourceScan.swiftSources(under: root) {
            let text = SourceScan.stripComments(
                try String(contentsOf: candidate, encoding: .utf8)
            )
            let key =
                candidate.path.hasPrefix(prefix)
                ? String(candidate.path.dropFirst(prefix.count))
                : candidate.path
            let hits = applyDoors.reduce(0) {
                $0 + text.occurrences(of: $1.verb)
            }
            guard hits > 0 else { continue }
            strays[key] = hits
        }
        #expect(
            strays == [
                "Profiles/KiwiCore+ProfileResolution.swift": 2
            ],
            Comment(
                rawValue:
                    "a verb that names which profile is live is "
                    + "spelled outside the apply doors (#1249)"
            )
        )
    }

    /// The store's write reaches it through one Core helper, and
    /// that helper is named only by the doors that move the name
    /// beside it. It spells no store, so the per-file
    /// `profilePartitioning` map above cannot see its callers —
    /// a third one would file the live Spaces under whatever name
    /// happened to be current, with nothing to red (#1249).
    /// Three sites in `KiwiCore+ProfileSpaces.swift`: the `func`
    /// line itself, which this needle matches like any call, plus
    /// the two doors that live beside it.
    private let recordCallers: [String: Int] = [
        "Profiles/KiwiCore+ProfileSpaces.swift": 3,
        "Profiles/KiwiCore+ProfileResolution.swift": 1,
    ]

    @Test("The partitioning record has three known callers")
    func partitioningRecordCallersAreCounted() throws {
        let root = coreRoot
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = source.occurrences(
                of: "recordLivePartitioning("
            )
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key] = hits
        }
        #expect(
            counts == recordCallers,
            Comment(
                rawValue:
                    "recordLivePartitioning moved or gained a "
                    + "caller; it files the live Spaces under "
                    + "profiles.currentName, so a caller that is "
                    + "not about to move that name files them "
                    + "under the wrong profile (#1249)"
            )
        )
    }
}
