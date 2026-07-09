import AppKit
import SwiftUI

/// Resigns the settings window's first responder when the user
/// clicks outside the currently-edited text field (#93).
///
/// Several settings fields (`StepperRow`, `ColorSwatch`'s hex
/// field, `SpaceNameField`) use `@FocusState` and commit on focus
/// loss — but on macOS, clicking empty/non-focusable space does
/// NOT resign a `TextField`'s first responder the way it does on
/// iOS, so a typed value can stick uncommitted until Return or a
/// click into another field.
///
/// A transparent tap layer can't fix this: the section
/// `ScrollView`s and every control claim the mouse-down before it
/// reaches a sibling behind them. So this installs a window-scoped
/// `NSEvent` local monitor, independent of SwiftUI hit-testing: on
/// a left mouse-down, if a field editor holds focus and the click
/// landed outside it, resign — which fires each field's
/// commit-on-focus-loss path.
struct ClickAwayResignsFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        FocusResignMonitorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Owns a left-mouse-down monitor scoped to its own window. The
/// monitor is torn down (and re-installed) in `viewDidMoveToWindow`
/// whenever the view's window changes — including leaving the
/// window (`window == nil`), which is the teardown path — so no
/// `deinit` is needed (a nonisolated `deinit` can't touch the
/// `@MainActor` monitor state anyway). Never intercepts clicks
/// itself (`hitTest` returns nil).
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

    /// Keep editing when the click lands inside the focused field
    /// editor; otherwise resign so the field commits. A no-op
    /// unless a text field editor currently holds focus, so plain
    /// clicks never disturb button/menu behaviour.
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
