import Foundation
import Testing

@testable import KiwiDesk

/// The Profiles views are wired to the gate resolver (#678 Phase
/// 3, turn 13a), split from the behaviour suite so neither file
/// crosses the size ceiling.
///
/// General shipped a round-1 cut whose resolver was built only in
/// tests while the views re-derived each predicate and re-authored
/// each sentence inline; the census gate and the on-screen grey
/// could then drift with every gate test still green. This is the
/// wiring half — the behaviour half is `ProfilesGateTests`.
///
/// SCOPE: by explicit path, one entry per GATE rather than per
/// file. `NativeSpacesGroup` resolves one gate that has two
/// reasons, and a file-level "touches the resolver somewhere"
/// check would pass while one of them went hand-rolled — the very
/// drift this guard exists to catch. A future gated row in this
/// area owes both its resolver consult AND a `consults` entry
/// naming the file that draws it, in the same change;
/// `everyGatedRowIsResolved` forces the resolver half, and
/// nothing but this map forces the view half.
@Suite("Profiles gate wiring")
struct ProfilesGateWiringTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// `path` is relative to `Settings/`, so the map below can
    /// name files in either `Components/Profiles/` or
    /// `Sections/`.
    private func read(_ path: String) throws -> String {
        try String(
            contentsOf: settingsDir.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    @Test("each gate is wired to the resolver, not a copy")
    func rowsConsultTheResolver() throws {
        // Whitespace-free source, so a needle survives the
        // formatter wrapping an `inertReason(for:)` call across
        // lines.
        func squashed(_ name: String) throws -> String {
            SourceScan.stripComments(try read(name))
                .split(whereSeparator: \.isWhitespace)
                .joined()
        }
        let consults: [String: [String]] = [
            "Components/Profiles/NativeSpacesGroup.swift": [
                "inertReason(for:.profiles(.profileBindings))"
            ],
            "Sections/PresetsSection.swift": [
                "inertReason(for:.profiles(.presetsApply))"
            ],
        ]
        for (name, needles) in consults {
            let source = try squashed(name)
            for needle in needles {
                #expect(
                    source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) no longer wires `\(needle)` "
                            + "to the gate resolver — that gate "
                            + "went hand-rolled"
                    )
                )
            }
            #expect(
                source.contains("ProfilesGateHelp.sentence"),
                Comment(
                    rawValue:
                        "\(name) does not read ProfilesGateHelp "
                        + "for its inert caption"
                )
            )
        }
        try sentencesAreAuthoredOnce(Array(consults.keys))
    }

    /// Every gate sentence is authored ONCE, in the help enum; a
    /// row that re-authors one is the duplication that let
    /// General describe one status two ways.
    ///
    /// Stated limit: this reads the NAMED files only, so a gate
    /// sentence re-authored anywhere else under `Settings/` is
    /// invisible to it. A new file in this area joins the list.
    /// It also reads raw source including comments, so a comment
    /// quoting a key reds it — fail-closed, and cheap to fix.
    private func sentencesAreAuthoredOnce(
        _ consulting: [String]
    ) throws {
        let help = try read(
            "Components/Profiles/ProfilesGates.swift"
        )
        let nonAuthors =
            consulting + [
                "Sections/ProfilesSection.swift",
                "Sections/ProfilesSection+WhichLoads.swift",
            ]
        for key in [
            "profiles.native_spaces.live_only",
            "native_spaces.separate_warning",
            "presets.editing_stored",
            "presets.needs_screens",
        ] {
            #expect(
                help.contains(key),
                Comment(rawValue: "ProfilesGateHelp lost \(key)")
            )
            for name in nonAuthors {
                #expect(
                    !(try read(name)).contains(key),
                    Comment(
                        rawValue:
                            "\(name) re-authors \(key) — it must "
                            + "come from ProfilesGateHelp"
                    )
                )
            }
        }
    }
}
