import AppKit
import KiwiDeskCore
import SwiftUI

/// Owns the dashboard window and its view model.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private var window: NSWindow?

    /// Initial open and minimum restore width
    /// (`SettingsWidthClass.panelBreakpoint`).
    static let firstRunWidth = SettingsWidthClass.panelBreakpoint
    init(core: KiwiCore) {
        self.model = SettingsModel(core: core)
        super.init()
        observeWorkspaceTopology()
    }

    /// Listens for display and space changes to refresh profile topology
    /// snapshots (#678).
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
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace
                .activeSpaceDidChangeNotification,
            object: nil,
            queue: .main,
            using: refresh
        )
    }

    /// Routes paused-permission banner's "Open System Settings" button.
    func setResolvePermission(_ handler: @escaping () -> Void) {
        model.onResolvePermission = handler
    }

    /// Routes broken-profile row reveal action (#246).
    func setRevealProfile(
        _ handler: @escaping (String) -> Void
    ) {
        model.onRevealProfile = handler
    }

    /// Sets why window management is not running (#2050).
    func setCoreHold(_ hold: CoreHold) {
        model.coreHold = hold
    }

    /// Routes the not-tiling banner's Start Tiling (#2050).
    func setStartTiling(_ handler: @escaping () -> Void) {
        model.onStartTiling = handler
    }

    /// Routes welcome tour replay (#678).
    func setShowTour(_ handler: @escaping () -> Void) {
        model.onShowTour = handler
    }

    /// The one update channel, shared with the status item so the
    /// footer, About and the menu-bar mark read one store (#1536).
    func setUpdater(_ updater: any AppUpdating) {
        model.updater = updater
    }

    /// A Keep or `save_profile` just wrote the live profile: move
    /// the draft's saved baseline onto what it wrote without
    /// discarding staged edits (#1179, #1790).
    func adoptKeptLayout(_ write: CapturedWrite) {
        model.adoptKeptLayout()
        if write == .wholeLive { model.adoptCapturedSpaces() }
    }

    /// Whether a live-profile draft holds edits a Save would
    /// write over a tour paint (#1720); a stored profile's cannot.
    var hasUnsavedDraft: Bool { model.isDirty && model.target == .live }

    /// Re-reads saved profiles list without discarding staged edits (#246).
    func refreshProfiles() {
        model.refreshProfiles()
    }

    /// Shows Settings where a bar menu's row lands (#1518): the
    /// page, and the card or row on it, as the search would.
    func show(landing: SettingsLanding) {
        model.land(on: SettingsAnchor(landing: landing))
        show()
    }

    /// Shows Settings on a What's new spotlight row's control,
    /// with the way back (#2038 ruling ▸ handoff); `show()` is the
    /// own-window door (#1281).
    func follow(_ trail: WhatsNewTrail) {
        model.follow(trail)
        show()
    }

    /// The trail's window is in front again or answered: the
    /// banner goes, nothing is called back.
    func endWhatsNewTrail() {
        model.whatsNewTrail = nil
    }

    /// The live Spaces the profile does not hold changed (#1790).
    func showLiveOnlySpaces(_ spaces: [LiveOnlySpace]) {
        model.liveOnlySpaces = spaces
    }

    /// A write of the live profile from outside Settings — the
    /// tour's look (#1720), a bar menu's row (#1518), a Space added
    /// or removed (#1790).
    func adoptLiveWrite(_ edit: LiveProfileEdit, persisted: Bool) {
        model.adoptLiveWrite(edit, persisted: persisted)
    }

    /// Shows dashboard navigated to destination (#326).
    func show(navigatingTo destination: SettingsDestination) {
        model.land(on: SettingsAnchor(destination: destination))
        show()
    }

    /// Shows the dashboard window: a fresh open on Home, an open
    /// one where it is (`SettingsModel.prepareToShow`, #1970).
    func show() {
        model.prepareToShow(
            windowShown: window.map {
                $0.isVisible || $0.isMiniaturized
            } ?? false
        )
        if let window {
            // Core first (#1281): a bare order-front of a window
            // the row just panned out reports a clickless focus,
            // which #1161's placement distrust bounces.
            model.core.focusOwnWindow(number: window.windowNumber)
            NSApp.forceFront(window)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.firstRunWidth,
                height: 620
            ),
            styleMask: [
                .titled, .closable, .miniaturizable,
                .resizable, .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )
        SettingsWindowTitle.follow(model, in: window)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
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
        // Tiled window ID for AX bridge discrimination
        // (#678, OwnWindowTiling).
        window.identifier = NSUserInterfaceItemIdentifier(
            OwnWindowTiling.identifier
        )
        window.center()
        window.setFrameAutosaveName("KiwiDeskSettings")
        // Clamp frame to shell minimum (`SettingsWidthClass.minimum`).
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

    /// Disarms recorder and cleans up state on window close (#213, #515).
    func windowWillClose(_ notification: Notification) {
        model.setRecorderArmed(false)
        model.cancelPendingDiscard()
        ColorPanelController.shared.dismiss()
        model.settingsClosed()
    }
}
