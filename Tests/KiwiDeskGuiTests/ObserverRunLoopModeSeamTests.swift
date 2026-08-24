import Foundation
import Testing

/// Issue #953: choosing the right run loop mode is only half the
/// obligation — the other half is that the choice REACHES the
/// run loop, and that the add and the remove name the same mode.
///
/// `OwnWindowGestureDeliveryTests` pins the chooser
/// (`AXApplicationObserver.runLoopModes(pid:)`) and nothing else,
/// which a guard-prover run showed is not enough: leaving the
/// chooser correct and hardcoding `.defaultMode` back at the
/// registration site restores bug #953 in full — our own
/// window's live resize goes unobserved again — with that suite
/// still green.
///
/// The remove half has no observable failure at all. An
/// `invalidate()` that removes the source from a mode the add
/// never used leaves it installed in the run loop afterwards,
/// which no test can see and no user reports.
///
/// So both `CFRunLoop{Add,Remove}Source` sites must iterate
/// the one stored `runLoopModes` list, and a mode literal may
/// appear only inside the chooser that owns the decision.
@Suite("Observer run loop mode wiring (#953)")
struct ObserverRunLoopModeSeamTests {
    private let calls = [
        "CFRunLoopAddSource",
        "CFRunLoopRemoveSource",
    ]

    private var observer: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/AX/AXApplicationObserver.swift"
            )
    }

    /// The final argument of every `call` in `source` — the run
    /// loop mode each site names.
    private func modeArguments(
        of call: String,
        in source: String
    ) -> [String] {
        let characters = Array(source)
        let marker = Array(call)
        var found: [String] = []
        var index = 0
        while index + marker.count <= characters.count {
            guard
                Array(
                    characters[index..<(index + marker.count)]
                ) == marker
            else {
                index += 1
                continue
            }
            var cursor = index + marker.count
            guard
                let arguments = SourceScan.balanced(
                    characters,
                    from: &cursor,
                    open: "(",
                    close: ")"
                )
            else {
                index += 1
                continue
            }
            found.append(
                arguments.split(separator: ",")
                    .last
                    .map {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    } ?? ""
            )
            index = cursor
        }
        return found
    }

    @Test("Both registration sites iterate the stored modes")
    func registrationSitesReadTheStoredModes() throws {
        let source = try SourceScan.strippedSource(at: observer)
        for call in calls {
            let modes = modeArguments(of: call, in: source)
            // Presence canary first: a scan that matched nothing
            // would otherwise pass for having found no
            // violations rather than for there being none.
            #expect(
                !modes.isEmpty,
                Comment(rawValue: "\(call) site not found")
            )
            for mode in modes {
                #expect(
                    mode == "mode",
                    Comment(
                        rawValue: "\(call) names \(mode) rather "
                            + "than the loop's stored mode — an "
                            + "add and a remove covering "
                            + "different modes strand the "
                            + "source in the run loop (#953)"
                    )
                )
            }
        }
    }

    @Test("Only the chooser names the default mode")
    func defaultModeLivesInTheChooserAlone() throws {
        let source = try SourceScan.strippedSource(at: observer)
        let chooser = try SourceScan.functionBody(
            of: "runLoopModes",
            in: "AXApplicationObserver.swift",
            under: "AX"
        )
        #expect(
            !chooser.isEmpty,
            "runLoopModes(pid:) body not found"
        )
        let inFile = source.occurrences(of: ".defaultMode")
        let inChooser = chooser.occurrences(of: ".defaultMode")
        #expect(inChooser > 0, "the chooser named no mode")
        #expect(
            inFile == inChooser,
            Comment(
                rawValue: ".defaultMode is named \(inFile) "
                    + "times but only \(inChooser) inside "
                    + "runLoopModes(pid:) — a registration site "
                    + "hardcoding a mode restores #953 with the "
                    + "chooser still correct"
            )
        )
    }

    @Test("The common modes are never registered")
    func commonModesAreNeverNamed() throws {
        let source = try SourceScan.strippedSource(at: observer)
        #expect(
            source.occurrences(of: ".commonModes") == 0,
            Comment(
                rawValue: "`.commonModes` additionally "
                    + "carries NSModalPanelRunLoopMode, "
                    + "which would deliver own-pid AX "
                    + "callbacks inside every runModal() "
                    + "session. #953 needs the "
                    + "event-tracking mode and nothing "
                    + "else — name the two modes."
            )
        )
    }
}
