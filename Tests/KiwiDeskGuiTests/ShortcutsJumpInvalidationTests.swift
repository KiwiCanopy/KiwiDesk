import CoreGraphics
import Foundation
import Observation
import Testing

@testable import KiwiDesk

/// A changed jump reading re-renders the bar and never the page
/// under it (#1520): the section body re-reads every row and the
/// host's symbolic-hotkey table, so invalidating it at each
/// marking change stuttered the scroll.
@Suite("Shortcuts jump bar invalidation")
@MainActor
struct ShortcutsJumpInvalidationTests {
    private func frame(_ top: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: 0, y: top, width: 400, height: height)
    }

    /// Focus's header at the bar, the content scrolled under it.
    private var focusUnderTheBar: [String: CGRect] {
        [
            ShortcutsJumpGroup.gestures.control.id: frame(-300, 80),
            ShortcutsJumpGroup.focus.control.id: frame(0, 400),
        ]
    }

    private var scrolled: [ShortcutsJumpSlot: CGRect] {
        [.content: frame(-300, 1900), .viewport: frame(0, 500)]
    }

    /// Whether `body` writes `tracker.reading`.
    private func notifies(
        _ tracker: ShortcutsJumpTracker,
        _ body: () -> Void
    ) -> Bool {
        let flag = Flag()
        withObservationTracking {
            _ = tracker.reading
        } onChange: {
            flag.fired = true
        }
        body()
        return flag.fired
    }

    /// `onChange` runs synchronously inside the write, on this
    /// actor; the box only satisfies its `@Sendable` signature.
    private final class Flag: @unchecked Sendable {
        var fired = false
    }

    /// The tracker carries the reading the bar observes, and an
    /// unchanged reading notifies nobody: the preferences
    /// re-measure on every scroll frame.
    @Test("the reading is published, and only when it changes")
    func publishesOnlyChanges() {
        let tracker = ShortcutsJumpTracker()
        tracker.sections(focusUnderTheBar)
        let changed = notifies(tracker) {
            tracker.slots(scrolled)
        }
        #expect(changed)
        #expect(tracker.reading.marked == .focus)
        #expect(tracker.reading.underlapped)
        let repeated = notifies(tracker) {
            tracker.slots(scrolled)
            tracker.sections(focusUnderTheBar)
        }
        #expect(!repeated)
        let jumped = notifies(tracker) {
            tracker.jump(to: .sizeFloat)
        }
        #expect(jumped)
        #expect(tracker.reading.marked == .sizeFloat)
    }

    // MARK: - Wiring

    private static func strippedSources() throws -> [(String, String)] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        return try SourceScan.swiftSources(under: root).map {
            (
                $0.lastPathComponent,
                SourceScan.stripComments(
                    try String(contentsOf: $0, encoding: .utf8)
                )
                .split(whereSeparator: \.isWhitespace)
                .joined()
            )
        }
    }

    /// The bar is the one reader of the tracker's reading, the
    /// section keeps no copy of it and holds the tracker in plain
    /// `@State` — an observed object would invalidate it again.
    @Test("only the jump bar reads the jump reading")
    func onlyTheBarReadsTheReading() throws {
        let sources = try Self.strippedSources()
        let readers = sources.filter { _, text in
            text.contains("Tracker.reading")
                || text.contains("tracker.reading")
        }
        #expect(readers.map(\.0) == ["ShortcutsJumpBar.swift"])
        let bar = try #require(
            readers.first { $0.0 == "ShortcutsJumpBar.swift" }
        )
        #expect(bar.1.contains("lettracker:ShortcutsJumpTracker"))
        #expect(bar.1.contains("marked:tracker.reading.marked==group"))
        #expect(bar.1.contains("iftracker.reading.underlapped{"))
        let section = sources.filter {
            $0.0.hasPrefix("ShortcutsSection")
        }
        #expect(section.count >= 2)
        for (name, text) in section {
            #expect(
                !text.contains("ShortcutsJumpReading"),
                "\(name) keeps a copy of the jump reading"
            )
        }
        #expect(
            section.contains {
                $0.1.contains(
                    "@StatevarjumpTracker=ShortcutsJumpTracker()"
                )
            }
        )
        // `@Observable`, not `ObservableObject`: the compiler then
        // refuses a `@StateObject` or `@ObservedObject` of it.
        let tracker = try #require(
            sources.first { $0.0 == "ShortcutsJump.swift" }
        )
        #expect(
            tracker.1.contains(
                "@MainActor@ObservablefinalclassShortcutsJumpTracker{"
            )
        )
    }
}
