import AppKit
import KiwiDeskCore
import SwiftUI

/// Owns the dashboard window and its view model. Kept alive by
/// `AppDelegate` so the window survives being closed and
/// reopened from the menu bar.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private var window: NSWindow?

    /// The width a window opens at when it has no saved frame,
    /// and the width a too-narrow saved frame is restored to.
    ///
    /// The widest band's floor, and derived rather than chosen
    /// beside it (17a). It was 860 — picked when nothing
    /// degraded and any width above the minimum was as good as
    /// another. Now 860 names the COMPACT band, so that default
    /// would have opened every first launch into two-line rows
    /// and a docked save bar: a user meeting the app for the
    /// first time in the most degraded arrangement it has,
    /// having asked for nothing. Opening at the panel
    /// breakpoint shows the shell as designed — docked preview,
    /// rows on their shared axis — and the bands still take
    /// over the moment the window is resized or tiled.
    static let firstRunWidth = SettingsWidthClass.panelBreakpoint
    init(core: KiwiCore) {
        self.model = SettingsModel(core: core)
        super.init()
        observeWorkspaceTopology()
    }

    /// Re-snapshots what the dashboard says about the MACHINE
    /// when the machine changes under it (#678 turn 13a).
    ///
    /// Several answers on the Profiles page are snapshots taken
    /// at refresh time: which profile resolves (a Desktop
    /// binding outranks monitor matching), whether a Desktop
    /// binding is ambiguous (separate Spaces AND more than one
    /// display), and which Desktop wears the "current" badge.
    /// Nothing refreshed them once the window was open, so
    /// plugging in a monitor or switching Desktop left a card
    /// saying "Right now:" about a moment that had passed — and
    /// the ambiguity gate answering for a display count that no
    /// longer held.
    ///
    /// Observed HERE rather than pushed from Core: the staleness
    /// belongs to this window, these are the standard AppKit
    /// notifications for exactly these two facts, and Core's own
    /// `.monitorChange` bus event is the Lua/CLI contract rather
    /// than a GUI refresh channel. `refreshProfiles` re-reads
    /// live state and touches no staged config, so this is safe
    /// mid-edit in a way `reload()` would not be.
    ///
    /// The observers are never removed, and that is deliberate
    /// rather than overlooked: `AppDelegate` builds exactly one
    /// of these and holds it for the process lifetime, precisely
    /// so the window survives close-and-reopen. A `deinit` that
    /// unregistered them would be unreachable code with an
    /// actor-isolation problem of its own. A second construction
    /// site would change that — and would want the tokens kept.
    private func observeWorkspaceTopology() {
        let refresh: @Sendable (Notification) -> Void = {
            [weak self] _ in
            MainActor.assumeIsolated { self?.refreshProfiles() }
        }
        _ = NotificationCenter.default.addObserver(
            forName: NSApplication
                .didChangeScreenParametersNotification,
            object: nil,
            queue: .main,
            using: refresh
        )
        // `NSWorkspace` posts to its OWN centre, not the default
        // one — a Space switch observed on `NotificationCenter`
        // .default never fires.
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace
                .activeSpaceDidChangeNotification,
            object: nil,
            queue: .main,
            using: refresh
        )
    }

    /// Routes the paused-permission banner's "Open System
    /// Settings" button; the app wires it to the macOS pane.
    func setResolvePermission(_ handler: @escaping () -> Void) {
        model.onResolvePermission = handler
    }

    /// Routes the broken-profile row's Reveal; the app wires it
    /// to the same handler the Config Issues panel uses, so one
    /// behaviour keeps one implementation (#246).
    func setRevealProfile(
        _ handler: @escaping (String) -> Void
    ) {
        model.onRevealProfile = handler
    }

    /// Drives the dashboard-wide paused banner: true while
    /// Accessibility is missing and window management is inert.
    func setPermissionPaused(_ paused: Bool) {
        model.permissionPaused = paused
    }

    /// Routes Home's "Show me around" to the welcome tour's
    /// voluntary replay (#678 turn 14c).
    func setShowTour(_ handler: @escaping () -> Void) {
        model.onShowTour = handler
    }

    /// Non-destructive refresh for the quick menu's layout
    /// actions: recomputes only the live-vs-saved drift
    /// captions, never reseeding `config` — staged edits
    /// survive a session layout switch.
    func refreshLayoutDrift() {
        model.refreshLayoutDrift()
    }

    /// Re-reads the saved-profiles list without discarding staged
    /// edits — so an open dashboard reflects a profile deleted
    /// from the Config Issues panel (#246).
    func refreshProfiles() {
        model.refreshProfiles()
    }

    /// Shows the dashboard already navigated to `destination` —
    /// the read-only shortcuts panel's "Edit in Settings…" bridge
    /// (#326). The request is one-shot; `SettingsView` clears it.
    func show(navigatingTo destination: SettingsDestination) {
        model.nav.pendingReveal = SettingsAnchor(
            destination: destination
        )
        show()
    }

    /// Shows the dashboard, refreshing from the backend so the
    /// active profile and any external config edits are current —
    /// except when the model holds unsaved edits.
    func show() {
        // Reopening must not discard an unsaved edit (#455). The
        // model is retained across close with its staged `config`
        // and its live-registered hotkeys intact; reseeding it from
        // `gui.json` here would drop the edit, clear the "Unsaved
        // changes" state, and roll the live hotkey back — the
        // "reopen loses my new shortcut" bug. Only a clean model
        // reloads, to pick up external edits (a profile switch, an
        // outside `gui.json` write). Mirrors the non-destructive
        // `refreshProfiles` / `refreshLayoutDrift` above.
        if !model.isDirty {
            model.reload()
        }
        // Home is the entry point for a first-run and a
        // returning user alike (turn 9 — the grid is the
        // overview §5.8 once sent to Profiles). The selection
        // lives on the model so it survives the locale re-key,
        // so the default has to be re-asserted on open rather
        // than falling out of `@State` being fresh. A deep link
        // set `pendingReveal` just above and still wins — the
        // view consumes it after this.
        model.destination = nil
        // The two surface selections live on the model too now
        // (#277), so they need the same re-assertion — otherwise
        // reopening Settings can land in the App Bar editor.
        model.nav.resetSurfaces()
        if let window {
            NSApp.forceFront(window)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                // Comfortably above the shell's hard
                // minimum on first launch — `firstRunWidth`
                // derives from it rather than restating a
                // number the bands own (17a).
                width: Self.firstRunWidth,
                height: 620
            ),
            styleMask: [
                .titled, .closable,
                .resizable, .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )
        window.title = L("app.name", "KiwiDesk")
        // Titlebar text hidden: the header bar carries the app
        // identity on Home and the area title when pushed.
        // `title` still names the Window menu.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // An empty unified toolbar keeps the traffic lights
        // over the header bar, which pulls up under it
        // (`ignoresSafeArea` in `SettingsView`), so no empty
        // toolbar strip shows above the header.
        let toolbar = NSToolbar()
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.contentView = NSHostingView(
            rootView: LocaleScopedRoot {
                SettingsView(model: model)
            }
            .environmentObject(LocalizationManager.shared)
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        // The one own window that tiles (#678 item 18): the
        // engine discriminates own windows per window, never
        // per process, and this identifier is the mark it
        // reads back through the AX bridge. The tour and the
        // Config Issues window stay unmarked on purpose —
        // `OwnWindowTiling`'s doc carries the argument.
        window.identifier = NSUserInterfaceItemIdentifier(
            OwnWindowTiling.identifier
        )
        window.center()
        window.setFrameAutosaveName("KiwiDeskSettings")
        // A frame saved by an older build can be narrower than
        // the shell's minimum; min-size only gates user
        // resizing, not the restore, so clamp once.
        //
        // Through `SettingsWidthClass.minimum`, never a literal
        // (17a): this restore is the one path that can seat the
        // window BELOW the narrowest band, so a second spelling
        // of the number here is precisely how the window comes
        // to open somewhere the bands do not describe.
        if window.frame.width < SettingsWidthClass.minimum {
            let content = window.contentRect(
                forFrameRect: window.frame
            )
            window.setContentSize(
                NSSize(
                    width: Self.firstRunWidth,
                    height: content.height
                )
            )
        }
        self.window = window

        NSApp.forceFront(window)
    }

    /// Teardown only — there is no activation policy to release,
    /// because `show()` raises none (see "Permanent accessory
    /// mode" in `docs/design-decisions.md`). What this does is
    /// disarm state the window would otherwise carry into its
    /// next appearance: the window itself survives
    /// (`isReleasedWhenClosed = false`) for the next `show()`.
    func windowWillClose(_ notification: Notification) {
        // Guaranteed disarm net (#213): the recorder normally
        // resumes hotkeys via the field's own teardown, but the
        // window is retained (`isReleasedWhenClosed = false`) and
        // merely ordered out, so a close route that never delivers
        // a local mouse-down / app-deactivation could leave the
        // hotkeys suspended. Idempotent — a no-op when nothing is
        // armed.
        model.setRecorderArmed(false)
        // Same class of state, same reasoning (#515): a parked
        // discard closure captured a view that is now gone, and
        // the retained window would carry it into the next
        // `show()` — a dialog about edits that no longer exist.
        model.cancelPendingDiscard()
        // Put the shared color panel away so it can't write
        // into the config after the window is gone.
        ColorPanelController.shared.dismiss()
    }
}
