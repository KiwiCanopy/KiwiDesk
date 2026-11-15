import AppKit
import Combine
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A row's conflict line acts on the field's re-checked offer (#34,
/// #3258): when the chord's holder changes while the line stands,
/// Steal takes it from the new holder, never the one named at the
/// refusal.
///
/// Main-actor spend: one hosted row in an offscreen window and short
/// run-loop spins.
@Suite("Shortcut key row re-checked offer (#3258)", .serialized)
@MainActor
struct ShortcutKeyRowOfferTests {
    /// Who holds Right ⌘H, and whose chord a Steal took.
    private final class Holder: ObservableObject {
        @Published var name = "Row A"
        var stolenFrom: [String] = []
    }

    private struct Row: View {
        @ObservedObject var holder: Holder

        var body: some View {
            ShortcutKeyRow {
                Text(verbatim: "Row B title")
                Spacer()
                refusing
            }
        }

        /// The field commits Right ⌘H on arrival, as a recording or a
        /// Sides pick would, and is refused.
        private var refusing: KeyRecorderField {
            var field = KeyRecorderField(
                name: "Row B",
                combo: "lcmd+h",
                // A new holder changes the row's reading, as
                // in a shortcut list, which re-renders the field.
                reading: ConflictReading(
                    severity: .sidesTaken([]),
                    sentence: "Taken by \(holder.name)"
                ),
                narrowing: nil,
                preflight: { [holder] combo in
                    guard combo == "rcmd+h" else { return nil }
                    let name = holder.name
                    return RecorderRejection(
                        combo: combo,
                        holder: name,
                        holderRowID: name,
                        steal: { holder.stolenFrom.append(name) }
                    )
                },
                onRecord: { _ in },
                onClear: {}
            )
            field.commitsOnAppear = "rcmd+h"
            return field
        }
    }

    private func spin() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    private func buttons(in view: NSView) -> [NSButton] {
        var out: [NSButton] = []
        if let button = view as? NSButton,
            String(describing: type(of: view)) == "SwiftUIAppKitButton"
        {
            out.append(button)
        }
        for sub in view.subviews { out += buttons(in: sub) }
        return out
    }

    /// The record well's frame in the host.
    private func ring(in view: NSView) -> CGRect? {
        if String(describing: type(of: view)) == "_FocusRingView",
            view.frame.width >= KeyRecorderField.labelMinWidth,
            let host = view.window?.contentView
        {
            return view.convert(view.bounds, to: host)
        }
        for sub in view.subviews {
            if let found = ring(in: sub) { return found }
        }
        return nil
    }

    @Test("Steal takes the chord from its holder now")
    func stealFollowsTheHolder() throws {
        LocalizationManager.shared.select("en")
        let holder = Holder()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 160),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        let host = NSHostingView(
            rootView: Row(holder: holder)
                .frame(width: 640, height: 160, alignment: .topLeading)
                .environmentObject(RecorderCoordinator())
                .environment(
                    \.recorderSides,
                    RecorderSides(hyperKey: nil)
                )
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        spin()
        spin()
        holder.name = "Row C"
        spin()
        // Steal is the leftmost action on the line under the well.
        let well = try #require(ring(in: host))
        let frame = { (button: NSButton) in
            button.convert(button.bounds, to: host)
        }
        let steal = try #require(
            buttons(in: host)
                .filter { frame($0).minY >= well.maxY }
                .min { frame($0).minX < frame($1).minX }
        )
        steal.performClick(nil)
        spin()
        #expect(holder.stolenFrom == ["Row C"])
    }
}
