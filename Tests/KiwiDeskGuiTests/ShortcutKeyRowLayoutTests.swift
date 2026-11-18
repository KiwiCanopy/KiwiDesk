import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A refused chord's Steal / Go to line is drawn under the row and
/// across it, while the title keeps its place beside the well (#3258
/// ▸ owner ruling). The row is seeded: a menu tracked in a test ends
/// the test process, so the Sides pick itself is a device check.
///
/// Main-actor spend: two hosted rows in an offscreen window and
/// run-loop spins until each row's awaited layout.
@Suite("Shortcut key row conflict line (#3258)", .serialized)
@MainActor
struct ShortcutKeyRowLayoutTests {
    /// Where the test's own title drew, in the host's coordinates.
    private final class Probe {
        var title: CGRect = .zero
    }

    private static func close(_ window: NSWindow) {
        window.orderOut(nil)
    }

    /// Runs the main run loop until `done` holds; the deadline
    /// only bounds a hang (tests.md ▸ await the handle, #3442).
    private func spin(until done: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !done(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    /// Row B at Left ⌘H; its preflight refuses Right ⌘H, row A's.
    /// A dead row draws a caption under its well, so the field's
    /// stack is taller than its well.
    private static let dead = ConflictReading(
        severity: .sidesTaken([]),
        sentence: "Dead row"
    )

    /// `commits` is a chord the field commits on arrival, as a
    /// recording or a Sides pick would.
    private func field(
        commits: String? = nil,
        reading: ConflictReading? = nil
    ) -> KeyRecorderField {
        var field = KeyRecorderField(
            name: "Row B",
            combo: "lcmd+h",
            reading: reading,
            narrowing: nil,
            preflight: { combo in
                guard combo == "rcmd+h" else { return nil }
                return RecorderRejection(
                    combo: combo,
                    holder: "Row A",
                    holderRowID: "a",
                    steal: {}
                )
            },
            onRecord: { _ in },
            onClear: {}
        )
        field.commitsOnAppear = commits
        return field
    }

    /// `ready` is the laid-out state the test reads, awaited.
    private func host<V: View>(
        _ view: V,
        width: CGFloat = 640,
        ready: (NSView) -> Bool
    ) -> (NSWindow, NSView) {
        let rooted =
            view
            .frame(width: width, height: 160, alignment: .topLeading)
            .coordinateSpace(name: "host")
            .environmentObject(RecorderCoordinator())
            .environment(\.recorderSides, RecorderSides(hyperKey: nil))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 160),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let host = NSHostingView(rootView: rooted)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        spin { ready(host) }
        return (window, host)
    }

    private func frames(
        of kind: String,
        in host: NSView
    ) -> [CGRect] {
        var out: [CGRect] = []
        func walk(_ view: NSView) {
            if String(describing: type(of: view)) == kind {
                out.append(view.convert(view.bounds, to: host))
            }
            view.subviews.forEach(walk)
        }
        walk(host)
        return out
    }

    /// The record well's focus ring, the well's own frame.
    private func wellLine(in host: NSView) throws -> CGRect {
        try #require(well(in: host))
    }

    /// The well's frame, nil until it has laid out.
    private func well(in host: NSView) -> CGRect? {
        // The badge carries a ring too; the well is the widest,
        // at least `labelMinWidth`.
        frames(of: "_FocusRingView", in: host)
            .max { $0.width < $1.width }
            .flatMap {
                $0.width >= KeyRecorderField.labelMinWidth ? $0 : nil
            }
    }

    /// Whether the well has laid out with `count` line buttons.
    private func drawn(_ count: Int, in host: NSView) -> Bool {
        guard let line = well(in: host) else { return false }
        return lineButtons(below: line, in: host).count == count
    }

    /// The conflict line's buttons: Steal, Go to, dismiss.
    private func lineButtons(below line: CGRect, in host: NSView)
        -> [CGRect]
    {
        frames(of: "SwiftUIAppKitButton", in: host)
            .filter { $0.minY >= line.maxY }
    }

    private func titled(_ probe: Probe) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "Row B title")
                .shortcutLineTitle()
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .named("host"))
                } action: {
                    probe.title = $0
                }
            Text(verbatim: "detail").font(.caption)
        }
    }

    private var refused: RecorderRejection {
        RecorderRejection(
            combo: "rcmd+h",
            holder: "Row A",
            holderRowID: "a",
            steal: {}
        )
    }

    @Test("a refused chord draws one line under the row, across it")
    func conflictLineSpansTheRow() throws {
        LocalizationManager.shared.select("en")
        let probe = Probe()
        let (window, host) = host(
            ShortcutKeyRow(seeded: refused) {
                titled(probe)
                Spacer()
                field(reading: Self.dead)
            }
        ) { drawn(3, in: $0) && probe.title != .zero }
        defer { Self.close(window) }
        let line = try wellLine(in: host)
        let buttons = lineButtons(below: line, in: host)
        // Steal, Go to and the dismissal, once: the field draws no
        // second row in its own column.
        #expect(buttons.count == 3)
        let mids = buttons.map(\.midY)
        #expect((mids.max() ?? 0) - (mids.min() ?? 0) < 1)
        // Across the row: it starts left of the well's column.
        let first = try #require(buttons.min { $0.minX < $1.minX })
        #expect(first.maxX < line.minX)
        // The title sits beside the well, not centred on the
        // taller stack.
        #expect(abs(probe.title.midY - line.midY) < 2)
    }

    @Test("a row with no refused chord draws no line")
    func noConflictNoLine() throws {
        LocalizationManager.shared.select("en")
        let probe = Probe()
        let (window, host) = host(
            ShortcutKeyRow {
                titled(probe)
                Spacer()
                field(reading: Self.dead)
            }
        ) { drawn(0, in: $0) && probe.title != .zero }
        defer { Self.close(window) }
        let line = try wellLine(in: host)
        #expect(lineButtons(below: line, in: host).isEmpty)
        #expect(abs(probe.title.midY - line.midY) < 2)
    }

    /// A narrow row wraps the sentence, its holder whole, and moves
    /// the actions under it rather than cutting the name.
    @Test("a narrow row wraps the line instead of truncating")
    func narrowRowWraps() throws {
        LocalizationManager.shared.select("en")
        let long = RecorderRejection(
            combo: "rcmd+h",
            holder: "Show or hide the Space Bar on every screen",
            holderRowID: "a",
            steal: {}
        )
        let (window, host) = host(
            ShortcutKeyRow(seeded: long) {
                Text(verbatim: "Row B title")
                Spacer()
                field()
            },
            width: 360
        ) { drawn(3, in: $0) }
        defer { Self.close(window) }
        let line = try wellLine(in: host)
        let buttons = lineButtons(below: line, in: host)
        #expect(buttons.count == 3)
        // The actions start their own line, under the sentence's
        // start, past a wrapped sentence.
        let first = try #require(buttons.min { $0.minX < $1.minX })
        #expect(first.minX < SettingsMetrics.shortcutTextIndent + 4)
        #expect(first.minY - line.maxY > 24)
    }

    /// The field's own refusal of Right ⌘H must reach the row's line
    /// (`recorderConflictSlot`).
    @Test("the field's refusal lands on the row's line")
    func fieldWritesTheRow() throws {
        LocalizationManager.shared.select("en")
        let (window, host) = host(
            ShortcutKeyRow {
                Text(verbatim: "Row B title")
                Spacer()
                field(commits: "rcmd+h")
            }
        ) { drawn(3, in: $0) }
        defer { Self.close(window) }
        let line = try wellLine(in: host)
        let buttons = lineButtons(below: line, in: host)
        #expect(buttons.count == 3)
        let first = try #require(buttons.min { $0.minX < $1.minX })
        #expect(first.maxX < line.minX)
    }
}
