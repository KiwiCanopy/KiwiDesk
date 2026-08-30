import AppKit
import SwiftUI

/// The ONE composition point for a row's action menu (#845):
/// right-click, VoiceOver actions and the `⌃.` chord from one
/// builder — never spell a channel beside the seam;
/// `KeyboardActionParityTests` reds on a bare one outside this
/// file.
///
/// Delivery is a key MONITOR plus a row-anchored popover, each the
/// residue of a shipped failure (#845 review + device QA
/// 2026-08-23): per-row `.keyboardShortcut` is window-scoped and
/// cross-targeted the FIRST row; a focus-gated hidden `Menu` never
/// hears AppKit-backed focus; nothing opens a `.contextMenu`
/// programmatically, and synthesized right-clicks proved
/// nondeterministic on device. A row joining the family must be
/// able to HOLD focus, and whether the chord LANDS is a device
/// fact — verify with keyboard navigation ON.
private struct RowActionFocusKey: FocusedValueKey {
    typealias Value = RowChordCatcher.Token
}

extension FocusedValues {
    /// Catcher of row holding SwiftUI focus (`KeyboardActionParityTests`).
    var rowActionFocus: RowChordCatcher.Token? {
        get { self[RowActionFocusKey.self] }
        set { self[RowActionFocusKey.self] = newValue }
    }
}

extension View {
    /// Attaches action menu to right-click, accessibility actions, and `⌃.`
    /// chord (#845).
    func rowActions<MenuContent: View>(
        @ViewBuilder _ menu: @escaping () -> MenuContent
    ) -> some View {
        modifier(RowActions(menu: menu))
    }
}

private struct RowActions<MenuContent: View>: ViewModifier {
    let menu: () -> MenuContent
    @State private var catcher = RowChordCatcher.Token()
    @State private var chordMenuShown = false
    @FocusedValue(\.rowActionFocus) private var current

    func body(content: Content) -> some View {
        content
            .contextMenu { menu() }
            .accessibilityActions { menu() }
            .focusedValue(\.rowActionFocus, catcher)
            .background(RowChordCatcher(token: catcher))
            .popover(
                isPresented: $chordMenuShown,
                attachmentAnchor: .rect(.bounds)
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    menu()
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .onAppear {
                let shown = $chordMenuShown
                catcher.openMenu = {
                    shown.wrappedValue = true
                }
            }
            .onChange(of: current === catcher) { _, isFocused in
                if isFocused {
                    RowChordMonitor.shared.noteFocused(
                        catcher.view
                    )
                } else if let view = catcher.view {
                    // Clear only our own claim: A→B focus moves
                    // deliver A's false AFTER B's true, and an
                    // unconditional nil would wipe B's.
                    RowChordMonitor.shared.clearFocused(
                        if: view
                    )
                }
            }
    }
}

/// Zero-size view publishing frame to monitor and anchoring
/// popovers (#845). One shared monitor serves every catcher —
/// installed on the first arrival, never removed: an app-lifetime
/// singleton, like the menus it serves.
struct RowChordCatcher: NSViewRepresentable {
    let token: Token

    @MainActor
    final class Token: NSObject {
        weak var view: CatcherView?
        var openMenu: (() -> Void)?
    }

    @MainActor
    final class CatcherView: NSView {
        weak var token: Token?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                RowChordMonitor.shared.register(self)
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.token = token
        token.view = view
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.token = token
        token.view = nsView
    }
}

/// Monitor intercepting `⌃.` shortcut and presenting focused row's action
/// popover (#845).
@MainActor
final class RowChordMonitor {
    static let shared = RowChordMonitor()

    private let catchers = NSHashTable<RowChordCatcher.CatcherView>
        .weakObjects()
    private var installed = false
    private weak var focusedCatcher: RowChordCatcher.CatcherView?

    func noteFocused(_ view: RowChordCatcher.CatcherView?) {
        focusedCatcher = view
    }

    func clearFocused(if view: RowChordCatcher.CatcherView) {
        if focusedCatcher === view { focusedCatcher = nil }
    }

    func register(_ view: RowChordCatcher.CatcherView) {
        catchers.add(view)
        guard !installed else { return }
        installed = true
        _ = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            let consumed = MainActor.assumeIsolated {
                Self.shared.consume(event)
            }
            return consumed ? nil : event
        }
    }

    /// Matches `⌃.` key event (`KeyboardActionParityTests`, #845).
    private func matchesChord(_ event: NSEvent) -> Bool {
        event.charactersIgnoringModifiers == "."
            && event.modifierFlags
                .intersection([
                    .command, .option, .control, .shift,
                ]) == .control
    }

    private func consume(_ event: NSEvent) -> Bool {
        guard matchesChord(event), let window = event.window
        else { return false }
        guard let target = target(in: window) else {
            return false
        }
        target.token?.openMenu?()
        return true
    }

    /// Resolves focused row catcher from SwiftUI token or AppKit responder
    /// frame containment.
    private func target(
        in window: NSWindow
    ) -> RowChordCatcher.CatcherView? {
        if let focused = focusedCatcher,
            focused.window === window
        {
            return focused
        }
        guard let responder = window.firstResponder as? NSView
        else { return nil }
        // FULL-frame containment, not a midpoint: under SwiftUI
        // focus the first responder is the hosting view, whose
        // frame is the whole window — a midpoint test would
        // false-match whichever row sits at window center.
        let rect = responder.convert(responder.bounds, to: nil)
        return catchers.allObjects.first { catcher in
            catcher.window === window
                && catcher.convert(catcher.bounds, to: nil)
                    .contains(rect)
        }
    }
}
