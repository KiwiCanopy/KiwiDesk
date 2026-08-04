import Foundation
import Testing

@testable import KiwiDesk

/// The dashboard re-reads the machine when the machine changes
/// (#678 turn 13a).
///
/// The Profiles page snapshots three answers about live hardware
/// — which profile resolves, whether a Desktop binding is
/// ambiguous, which Desktop is current. Nothing refreshed them
/// once the window was open, so plugging in a display or
/// switching Desktop left a card saying "Right now:" about a
/// moment that had passed.
///
/// A SOURCE guard, deliberately. The behaviour needs two real OS
/// notifications and a live window, which a unit test may not
/// reach (tests.md: a test touches the machine only through an
/// injected seam) — and the whole method was deletable green
/// before this existed (guard-prover, 2026-08-04). What is
/// pinned is that the observation exists, watches BOTH facts,
/// and lands on the non-destructive refresh.
///
/// Stated limit: a scan cannot prove the observers fire, nor
/// that `refreshProfiles` re-reads everything the page shows.
@Suite("Workspace topology observation")
struct WorkspaceTopologyObserverTests {
    private func controllerSource() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/"
                    + "SettingsWindowController.swift"
            )
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    /// Both facts, and each from the centre that actually posts
    /// it: `NSWorkspace` publishes the Space change on its OWN
    /// notification centre, so the same observation registered on
    /// `NotificationCenter.default` would never fire — a silent
    /// half-fix that looks right at the call site.
    @Test("the window observes both topology facts")
    func observesDisplaysAndSpaces() throws {
        let source = try controllerSource()
        #expect(
            source.contains(
                "NotificationCenter.default.addObserver("
            )
        )
        #expect(
            source.contains(
                "didChangeScreenParametersNotification"
            ),
            Comment(
                rawValue:
                    "the dashboard no longer watches display "
                    + "changes — its resolution card and its "
                    + "ambiguity gate both answer per display "
                    + "count"
            )
        )
        #expect(
            source.contains(
                "NSWorkspace.shared.notificationCenter"
                    + ".addObserver("
            ),
            Comment(
                rawValue:
                    "the Space observation moved off "
                    + "NSWorkspace's own centre, where it is "
                    + "posted — it would never fire"
            )
        )
        #expect(
            source.contains("activeSpaceDidChangeNotification"),
            Comment(
                rawValue:
                    "the dashboard no longer watches Desktop "
                    + "switches — a Desktop binding outranks "
                    + "monitor matching, so the verdict and the "
                    + "current badge both go stale"
            )
        )
    }

    /// The refresh must be the non-destructive one: `reload()`
    /// re-seeds `config` from disk and would discard whatever the
    /// user has staged, so a monitor being plugged in would eat
    /// their unsaved edits.
    @Test("the refresh is the edit-safe one")
    func refreshDoesNotDiscardEdits() throws {
        let source = try controllerSource()
        #expect(
            source.contains("self?.refreshProfiles()"),
            Comment(
                rawValue:
                    "the topology observation no longer calls "
                    + "refreshProfiles"
            )
        )
        #expect(
            !source.contains(
                "MainActor.assumeIsolated{self?"
                    + ".reload()"
            ),
            Comment(
                rawValue:
                    "a topology change must not reload — that "
                    + "discards staged edits"
            )
        )
    }
}
