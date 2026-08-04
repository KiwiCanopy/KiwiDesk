import Foundation
import Testing

@testable import KiwiDesk

/// The per-space override editors are wired to the gate resolver
/// (#678 Phase 3, turn 8), split from the behaviour suite so
/// neither file crosses the size ceiling.
///
/// General shipped a round-1 cut whose resolver was built only in
/// tests while the views re-derived each predicate and re-authored
/// each sentence inline; the census gate and the on-screen grey
/// could then drift with every gate test still green. This is the
/// wiring half — the behaviour half is `SpacesGateTests`.
///
/// SCOPE: this scans by explicit path under `Settings/`, since the
/// gated rows `SpacesGates` answers now render in TWO places — five
/// in the `.perSpaceOverrides` rows (`Components/SpaceOverrides/`)
/// and the active-layout reset in the pushed editor's header
/// (`Sections/SpacesSection+Overrides.swift`, #678 8b, which moved
/// the reset out of the footer). The `.spaceList` container drawn
/// by the other `SpacesSection*` files carries NO gated row, so it
/// stays unscanned. A future gated `.spaceList` row would be forced
/// into `SpacesGates.resolved` by `everyGatedRowIsResolved`, yet
/// nothing here would force its view to consult the resolver — the
/// dead-resolver trap. Such a row owes both its resolver consult
/// AND a `consults` entry naming the file that draws it (add its
/// path below), in the same change.
@Suite("Spaces & Layouts gate wiring")
struct SpacesGateWiringTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// `path` is relative to `Settings/`, so the map below can name
    /// files in either `Components/SpaceOverrides/` or `Sections/`.
    private func read(_ path: String) throws -> String {
        try String(
            contentsOf: settingsDir.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    /// EACH gate's own resolver call, not a file-level "touches the
    /// resolver somewhere". `SpaceOverrideRows+ModeRows` carries
    /// four gates across grid and track; a file check would pass
    /// while one quietly went hand-rolled — the very drift this
    /// guard exists to catch.
    @Test("each gate is wired to the resolver, not a copy")
    func rowsConsultTheResolver() throws {
        // Whitespace-free source, so a needle survives the
        // formatter wrapping a `gates.inertReason(for:)` call
        // across lines.
        func squashed(_ name: String) throws -> String {
            SourceScan.stripComments(try read(name))
                .split(whereSeparator: \.isWhitespace)
                .joined()
        }
        let overrides = "Components/SpaceOverrides/"
        let consults: [String: [String]] = [
            // The active-layout reset now lives in the pushed
            // editor's header (#678 8b), not the footer.
            "Sections/SpacesSection+Overrides.swift": [
                "gates.inertReason("
                    + "for:.spaces(.spaceOverrideResetActive))"
            ],
            overrides + "SpaceOverrideRows+StackRows.swift": [
                "gates.inertReason("
                    + "for:.layout(.stackOverrideMasterOrientation))"
            ],
            overrides + "SpaceOverrideRows+ModeRows.swift": [
                "gates.inertReason("
                    + "for:.layout(.gridOverrideFillEmptySpace))",
                "gates.inertReason("
                    + "for:.layout(.gridOverrideColumns))",
                "gates.inertReason("
                    + "for:.layout(.gridOverrideRows))",
                "gates.inertReason("
                    + "for:.layout(.trackOverrideLimit))",
            ],
        ]
        for (name, needles) in consults {
            let source = try squashed(name)
            for needle in needles {
                #expect(
                    source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) no longer wires `\(needle)` to "
                            + "the gate resolver — that gate went "
                            + "hand-rolled"
                    )
                )
            }
            #expect(
                source.contains("SpacesGateHelp.sentence"),
                Comment(
                    rawValue:
                        "\(name) does not read SpacesGateHelp for "
                        + "its inert caption"
                )
            )
        }
        // Every gate sentence is authored ONCE, in the help enum; a
        // row that re-authors one is the duplication that let
        // General describe one status two ways.
        let help = try read(overrides + "SpacesGates.swift")
        let nonAuthors =
            Array(consults.keys) + [
                overrides + "SpaceOverrideRows.swift",
                overrides + "OverrideSlotSizeRow.swift",
            ]
        for key in [
            "space_override.reset_active.none",
            "layout_params.master_orientation.one_master",
            "scroll_grid.fill_empty_space.rigid_only",
            "scroll_grid.auto_size.gates",
            "track.auto_tracks.gates",
        ] {
            #expect(
                help.contains(key),
                Comment(rawValue: "SpacesGateHelp lost \(key)")
            )
            for name in nonAuthors {
                #expect(
                    !(try read(name)).contains(key),
                    Comment(
                        rawValue:
                            "\(name) re-authors \(key) — it must "
                            + "come from SpacesGateHelp"
                    )
                )
            }
        }
    }
}
