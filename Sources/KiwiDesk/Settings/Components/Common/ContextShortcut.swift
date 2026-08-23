import AppKit
import SwiftUI

/// The ONE composition point for a row's action menu (#845).
///
/// A row hands its menu builder to `rowActions(_:)` ONCE, and
/// the seam applies it to every channel — right-click
/// (`.contextMenu`), VoiceOver (`.accessibilityActions`), and
/// the keyboard chord on the row that contains focus. A site
/// never spells a channel beside the seam: per-site application
/// is how a crossed pairing or a stale mirrored list ships, and
/// `KeyboardActionParityTests` reds on a bare channel outside
/// this file. A FOURTH channel joins here, once, and every row
/// has it.
///
/// The chord is `⌃.` (Control-Period — deliberately not `⌘.`,
/// macOS's Cancel equivalent), matched in ONE place below,
/// which the parity suite needles so prose stating the chord
/// cannot drift from the code.
///
/// DELIVERY is a key MONITOR plus a row-anchored popover, and
/// each half is the residue of a shipped failure (#845 review +
/// device QA 2026-08-23). The monitor, because per-row
/// `.keyboardShortcut` bindings are window-scoped and resolve
/// first-in-hierarchy — N identical bindings cross-targeted the
/// FIRST row's destructive items — and because a focus-gated
/// hidden `Menu` never received the key at all on AppKit-backed
/// controls (a `Picker`'s popup, a `TextField`), whose focus
/// lives in the AppKit responder chain and publishes no SwiftUI
/// `FocusedValues`; the chord just beeped. So the seam installs
/// ONE `NSEvent` local monitor for the whole app and resolves
/// the focused row itself, across BOTH focus worlds:
///
/// - SwiftUI-native focus (a `Button` tile) publishes the row's
///   catcher through `FocusedValues`, matched directly;
/// - AppKit-backed focus falls back to geometry — the row whose
///   catcher frame contains the first responder's frame (the
///   catcher is the row's `background`, so its frame IS the
///   row's; rows do not overlap).
///
/// And the popover, because nothing can open a `.contextMenu`
/// programmatically and a synthesized right-click pair proved
/// nondeterministic on device (one build selected the row
/// instead of opening its menu): the winner's row presents the
/// SAME builder's actions in a popover anchored at the row —
/// deterministic, Escape-dismissable — and the key event is
/// swallowed. No match (no row focused) returns the event
/// unhandled, so the system beep stays honest. The catcher
/// draws nothing and consumes no mouse-down, so `.draggable`
/// rows keep their drag. A row joining the family must be able
/// to HOLD focus at all (`SpaceAssignmentChip` takes
/// `.focusable()` for exactly this), and whether the chord
/// LANDS is a device fact — verify with keyboard navigation ON;
/// no headless guard can hear it.
private struct RowActionFocusKey: FocusedValueKey {
    typealias Value = RowChordCatcher.Token
}

extension FocusedValues {
    /// The catcher of the row whose subtree currently holds
    /// SwiftUI focus — nil under AppKit-backed focus, which the
    /// monitor's geometry fallback covers.
    var rowActionFocus: RowChordCatcher.Token? {
        get { self[RowActionFocusKey.self] }
        set { self[RowActionFocusKey.self] = newValue }
    }
}

extension View {
    /// Offers `menu` as the row's action menu on every channel:
    /// right-click, VoiceOver actions, and the `⌃.` chord while
    /// this row's subtree holds focus.
    func rowActions<MenuContent: View>(
        @ViewBuilder _ menu: @escaping () -> MenuContent
    ) -> some View {
        modifier(RowActions(menu: menu))
    }
}

private struct RowActions<MenuContent: View>: ViewModifier {
    let menu: () -> MenuContent
    @State private var catcher = RowChordCatcher.Token()
    /// The chord's presentation: a row-anchored panel of the
    /// SAME builder's actions. Not a native menu — nothing can
    /// open a `.contextMenu` programmatically, and synthesizing
    /// right-clicks proved nondeterministic on device (one
    /// build selected the row instead of opening its menu) —
    /// so the chord takes the one presentation SwiftUI can
    /// drive: deterministic, keyboard-dismissable, anchored.
    @State private var chordMenuShown = false
    /// The globally focused row's token, read back so THIS row
    /// can mirror "it is me" into the monitor — `FocusedValues`
    /// have no app-level observer to do it once.
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

/// The row-sized, draw-nothing view that (a) gives the monitor
/// the row's frame and window, and (b) is the thing a SwiftUI
/// focus publication names. One shared monitor serves every
/// catcher; it is installed on the first catcher's arrival and
/// never removed — an app-lifetime singleton, like the menus it
/// serves.
struct RowChordCatcher: NSViewRepresentable {
    let token: Token

    /// Identity + the live `NSView` the monitor measures + the
    /// row's own opener. A class on purpose: `FocusedValues`
    /// needs a stable, equatable token per row, and the monitor
    /// needs to reach the view and the opener from it.
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

/// The one chord monitor. `focusedCatcher` is fed by the
/// SwiftUI side (an app-wide `FocusedValue` observer would be a
/// second window's to fight over; instead each key press asks
/// the key window's hosting hierarchy afresh through the two
/// signals described on the seam's doc).
@MainActor
final class RowChordMonitor {
    static let shared = RowChordMonitor()

    /// Every live catcher, weakly — rows come and go with their
    /// `ForEach`.
    private let catchers = NSHashTable<RowChordCatcher.CatcherView>
        .weakObjects()
    private var installed = false

    /// The SwiftUI-focused row's catcher, published through
    /// `FocusedValues` and mirrored here by `RowActions` via
    /// `noteFocused(_:)` — nil when focus is AppKit-backed or
    /// nowhere.
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
        // Local monitors fire on the main thread; the Bool hop
        // exists because `assumeIsolated` requires a `Sendable`
        // return and `NSEvent` is not one.
        _ = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            let consumed = MainActor.assumeIsolated {
                Self.shared.consume(event)
            }
            return consumed ? nil : event
        }
    }

    /// `⌃.` — the one place the chord is spelled.
    private func matchesChord(_ event: NSEvent) -> Bool {
        event.charactersIgnoringModifiers == "."
            && event.modifierFlags
                .intersection([
                    .command, .option, .control, .shift,
                ]) == .control
    }

    /// True when the event was the chord AND a focused row took
    /// it (the caller then swallows it); false hands the event
    /// on — including a chord press with no row focused, whose
    /// system beep stays honest.
    private func consume(_ event: NSEvent) -> Bool {
        guard matchesChord(event), let window = event.window
        else { return false }
        guard let target = target(in: window) else {
            return false
        }
        target.token?.openMenu?()
        return true
    }

    /// The focused row's catcher: the SwiftUI publication when
    /// one is live in this window, else the row whose frame
    /// contains the AppKit first responder's frame.
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
        // FULL-frame containment, not a midpoint: under
        // SwiftUI-native focus the first responder is the
        // hosting view, whose frame is the whole window — a
        // midpoint test would false-match whichever row sits at
        // window center. A real AppKit control (a popup, the
        // field editor) fits inside its row; the hosting view
        // fits inside none.
        let rect = responder.convert(responder.bounds, to: nil)
        return catchers.allObjects.first { catcher in
            catcher.window === window
                && catcher.convert(catcher.bounds, to: nil)
                    .contains(rect)
        }
    }

}
