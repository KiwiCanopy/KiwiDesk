import AppKit
import SwiftUI

/// Resigns first responder when clicking outside an active text field (#93).
/// Uses an `NSEvent` local monitor so unfocusable clicks trigger commits.
struct ClickAwayResignsFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        FocusResignMonitorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Window-scoped monitor view for resigning text field focus.
private final class FocusResignMonitorView: NSView {
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitor()
        guard let window else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown]
        ) { [weak window] event in
            guard let window, event.window === window else {
                return event
            }
            Self.resignIfClickOutsideEditor(window, event)
            return event
        }
    }

    /// Resigns focus when a click occurs outside the active field editor.
    private static func resignIfClickOutsideEditor(
        _ window: NSWindow,
        _ event: NSEvent
    ) {
        guard let editor = window.firstResponder as? NSTextView
        else { return }
        let hit = window.contentView?.hitTest(
            event.locationInWindow
        )
        if let hit, hit.isDescendant(of: editor) { return }
        window.makeFirstResponder(nil)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
