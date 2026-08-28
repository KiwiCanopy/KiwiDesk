import Foundation
import Testing

@testable import KiwiDeskCore

/// The hold-to-repeat seams no behavioral suite can hold
/// (#1056). Every `HoldRepeatWiringTests` fixture hands in a
/// conforming fake and drives commands through `execute`, so
/// that suite stays green if the PRODUCTION registrar loses its
/// release channel, if a second dispatch entry bypasses the
/// tally, or if a fourth refusal cue forgets the funnel — the
/// "seam declared and never wired" class `tests.md` names. Each
/// test here pins one of those from the production side.
@MainActor
@Suite("Hold-to-repeat seams (#1056)")
struct HoldRepeatSeamTests {
    @Test("The production registrar keeps the release channel")
    func productionRegistrarIsReleaseCapable() {
        // Constructing the live center registers nothing (#565
        // is about `register` seizing chords), so this touches
        // no machine state. If `CarbonHotkeyCenter` ever stops
        // conforming to `HotkeyReleaseReporting` — or a wrapper
        // replaces it as the default — hold-to-repeat silently
        // never arms in the shipped app while every fake-driven
        // suite stays green; this is the two-sided pin.
        let manager = KeybindingManager(
            registrar: CarbonHotkeyCenter()
        )
        #expect(manager.holdRepeat.releaseCapable)
    }

    @Test("Repeatable verbs name real commands")
    func repeatableCommandsAreInTheCensus() {
        // `HoldRepeat.repeatableCommands` holds bare strings in
        // `Keys/`, far from the `Commands/Reference` census —
        // and §5 encourages verb renames. Deriving membership
        // from the census makes the rename red HERE instead of
        // leaving a repeat set that matches nothing.
        let census = Set(APIReference.commands.map(\.command))
        #expect(!HoldRepeat.repeatableCommands.isEmpty)
        for verb in HoldRepeat.repeatableCommands {
            #expect(census.contains(verb), "\(verb)")
        }
    }

    @Test("Every command reaches dispatch through the tally")
    func dispatchHasOneEntry() throws {
        // `KiwiCore.execute` tallies what a hotkey fire DID —
        // the repeat engine's one honest eligibility signal. A
        // second `dispatchCommand` caller would run commands
        // the tally never sees, so eligibility silently stops
        // meaning "what the press did".
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        var callers: [String] = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            for _
                in 0..<source.occurrences(
                    of: "dispatchCommand("
                )
            {
                callers.append(file.lastPathComponent)
            }
            if source.contains("func dispatchCommand(") {
                callers.removeLast()
            }
        }
        #expect(callers == ["KiwiCore+Execute.swift"])
    }

    @Test("Every size-limit cue routes through the one funnel")
    func refusalCuesShareTheFunnel() throws {
        // A cue that reaches the border seam without
        // `cueResizeRefusal` pills per tick under a held chord
        // — the wiring suite drives today's three cues but
        // cannot see a fourth that never joins. Derived, not
        // listed (#1056 guard-prover finding): every `refuse*`
        // function in the pill file routes through the funnel,
        // the funnel notes the refusal, and the funnel is the
        // ONE production caller of `borders.onResizeRefusal`.
        let pill = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDeskCore/App"
                )
                .appendingPathComponent(
                    "KiwiCore+SizeLimitPill.swift"
                )
        )
        let cues = pill.occurrences(of: "func refuse")
        #expect(cues >= 3)
        #expect(
            pill.occurrences(of: "cueResizeRefusal(") == cues + 1
        )
        let funnel = try SourceScan.functionBody(
            of: "cueResizeRefusal",
            in: "KiwiCore+SizeLimitPill.swift",
            under: "App"
        )
        #expect(funnel.contains("keys.noteResizeRefusal()"))
        #expect(funnel.contains("borders.onResizeRefusal("))

        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        var borderCueSites = 0
        for file in try SourceScan.swiftSources(under: root)
        where file.lastPathComponent != "BorderManager.swift" {
            borderCueSites +=
                try SourceScan
                .strippedSource(at: file)
                .occurrences(of: ".onResizeRefusal(")
        }
        #expect(borderCueSites == 1)
    }
}
