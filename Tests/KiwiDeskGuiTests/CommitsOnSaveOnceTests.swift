import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk

/// A commit request goes out once per chain of calls (#2584): a gate
/// and the leave it calls both ask, and a second commit in one turn
/// would re-commit a renamed Space against its old name.
///
/// Main-actor spend: one hosted field and two short spins.
@Suite("A commit request goes out once per turn (#2584)")
@MainActor
struct CommitsOnSaveOnceTests {
    private final class Count { var commits = 0 }

    private struct Probe: View {
        let count: Count
        @FocusState private var focused: Bool
        @State private var text = ""

        var body: some View {
            TextField("", text: $text)
                .commitsOnSave($focused) { count.commits += 1 }
        }
    }

    private func spin() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }

    @Test("Two requests in one chain commit once; the next turn again")
    func oncePerTurn() throws {
        let count = Count()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        window.contentView = NSHostingView(rootView: Probe(count: count))
        window.contentView?.layoutSubtreeIfNeeded()
        spin()
        let field = try #require(
            window.contentView.flatMap(Self.textField(in:))
        )
        #expect(window.makeFirstResponder(field))
        spin()
        let model = makeTestModel()
        model.commitFocusedField()
        model.commitFocusedField()
        #expect(count.commits == 1)
        spin()
        model.commitFocusedField()
        #expect(count.commits == 2)
    }

    private static func textField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        for sub in view.subviews {
            if let found = textField(in: sub) { return found }
        }
        return nil
    }
}
