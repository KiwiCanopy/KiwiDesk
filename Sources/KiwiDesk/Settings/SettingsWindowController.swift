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

    /// Sets whether dashboard displays permission paused banner.
    func setPermissionPaused(_ paused: Bool) {
        model.permissionPaused = paused
    }

    /// Routes welcome tour replay (#678).
    func setShowTour(_ handler: @escaping () -> Void) {
        model.onShowTour = handler
    }

    /// Non-destructive refresh for layout drift captions.
    func refreshLayoutDrift() {
        model.refreshLayoutDrift()
    }

    /// Re-reads saved profiles list without discarding staged edits (#246).
    func refreshProfiles() {
        model.refreshProfiles()
    }

    /// Shows dashboard navigated to destination (#326).
    func show(navigatingTo destination: SettingsDestination) {
        model.nav.pendingReveal = SettingsAnchor(
            destination: destination
        )
        show()
    }

    /// Shows dashboard window, reloading config if not dirty (#455).
    func show() {
        if !model.isDirty {
            model.reload()
        }
        model.destination = nil
        model.nav.resetSurfaces()
        if let window {
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
        window.title = L("app.name", "KiwiDesk")
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
    }
}
