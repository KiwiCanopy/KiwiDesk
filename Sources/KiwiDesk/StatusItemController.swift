import AppKit
import KiwiDeskCore
import SwiftUI

/// Owns the menu bar item: the status icon's state machine
/// (§3.7) — permission warning beats config error beats the
/// active mode's custom icon beats the standard glyph. The quick
/// menu (#68 §3.10) is built in `StatusItemController+Menu`.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    var onOpenDashboard: () -> Void = {}
    /// Opens the read-only shortcuts reference panel (#326).
    var onShowShortcuts: () -> Void = {}
    var onShowConfigIssues: () -> Void = {}
    /// The combo bound to open the shortcuts panel (#330), or nil
    /// when unbound. Read fresh on each menu open so AppKit renders
    /// the live binding in its native shortcut column (like
    /// `profilesProvider`).
    var shortcutsComboProvider: () -> KeyCombo? = { nil }
    /// Opens the guided permission fix (the onboarding wizard at
    /// its grant step). Wired unconditionally; the *row* that
    /// invokes it appears only while Accessibility is missing.
    var onShowAccessibilityHelp: () -> Void = {}
    var onLoadProfile: (String) -> Void = { _ in }
    /// The saved profiles, the active one, and the unreadable
    /// ones, pulled fresh each menu open. Broken entries stay
    /// listed but disabled — greyed, not hidden; the remedy is
    /// the Config Issues panel, one entry up (#246, #171).
    var profilesProvider:
        () -> (
            active: String?, all: [String], broken: Set<String>
        ) = { (nil, [], []) }
    /// Provider for active layout mode and active profile status.
    var layoutInfoProvider:
        () -> (
            activeMode: LayoutMode?,
            activeProfileName: String?,
            savedModeForActiveSpace: LayoutMode?
        ) = { (nil, nil, nil) }
    var onSetLayoutMode: (LayoutMode) -> Void = { _ in }
    var onSaveLayoutToProfile: () -> Void = {}

    /// The menu-bar slot — injected so tests can build the
    /// quick-menu logic without registering a real system item
    /// (see `StatusItemHandle`, the #565-class seam).
    private let item: StatusItemHandle
    private let menu = NSMenu()
    /// Missing-permission warning overrides everything.
    /// `private(set)`: the menu builder in `+Menu` reads it to add
    /// the "Window Management Paused…" row, but only `setWarning`
    /// may mutate it — every write must go through `render()`.
    private(set) var warning = false
    /// The last config load left issues (§3.7) — a distinct
    /// badge so the two causes are never confused. `private(set)`
    /// for the same reason as `warning` (drives the Config Issues
    /// row; mutated only via `setConfigError`).
    private(set) var configError = false
    /// Active keybinding mode indicator (SF Symbol or emoji);
    /// nil restores the standard KiwiDesk icon.
    private var modeIcon: String?
    /// The last published boot phase — the whole readiness signal
    /// (#802), read by the icon AND by the menu builder.
    ///
    /// ONE stored value rather than a pushed flag beside a pulled
    /// provider: `core.bootPhase` returns exactly what `publish`
    /// just handed over, so a pull is never fresher, and two reads
    /// of one fact let a surface wired to only one of them show
    /// half the signal — a dimmed mark over an un-greyed menu
    /// (architect review, 2026-08-12).
    private(set) var bootPhase: BootPhase = .ready
    /// The open menu's starting row, while one is open. Held so a
    /// phase published mid-tracking can retitle it in place: the
    /// row is built once per open, and on a heavy session the menu
    /// is open for most of the boot it is reporting (owner, on
    /// device, 2026-08-12).
    weak var startingRow: NSMenuItem?

    /// `nil` means the live system slot. The optional-with-nil
    /// shape, rather than `= SystemStatusItem()`, is what lets
    /// the wrapper below stay file-scoped `private` — a
    /// default-argument expression cannot reference a type less
    /// accessible than the init, but the body can.
    init(item: (any StatusItemHandle)? = nil) {
        self.item = item ?? SystemStatusItem()
        super.init()
        menu.delegate = self
        self.item.menu = menu
        render()
    }

    // MARK: - Icon states

    /// Toggles the missing-permission warning icon.
    func setWarning(_ warning: Bool) {
        self.warning = warning
        render()
    }

    /// Toggles the config-error badge (§3.7): shown when the
    /// last config load reported issues; permission warnings
    /// still win (without Accessibility nothing works
    /// regardless of config validity).
    func setConfigError(_ error: Bool) {
        configError = error
        render()
    }

    /// Reflects how far the boot has got (#802).
    ///
    /// Two cheap consequences per chunk: the icon re-renders only
    /// on the starting↔ready flip, and an open menu's count row is
    /// retitled in place. Everything else the menu draws off the
    /// phase (the greys) cannot change without that flip, so the
    /// row is the only live piece.
    func setBootPhase(_ phase: BootPhase) {
        let wasStarting = bootPhase.isStarting
        bootPhase = phase
        if let startingRow, case .scanning = phase {
            startingRow.title = Self.startingTitle(for: phase)
        }
        guard phase.isStarting != wasStarting else { return }
        render()
    }

    /// Whether the readiness signal is owed. Ranked below the
    /// permission warning and above the config error: without
    /// Accessibility nothing works regardless of how far a boot
    /// got, while a config problem is a thing to fix once the app
    /// can be clicked at all. Derived, never stored — one fact,
    /// one place (architect review, 2026-08-12).
    var starting: Bool { bootPhase.isStarting }

    /// Reflects the active keybinding mode: a custom mode's
    /// icon replaces the standard menu bar glyph; the default
    /// mode (nil) restores it.
    func setModeIcon(_ icon: String?) {
        modeIcon = icon
        render()
    }

    /// The live button, for a surface that must point AT the menu
    /// bar item rather than drive it — the one-time coach mark
    /// (#678 Phase 4 pass 11). Read-only and nil behind the test
    /// seam, which is what makes "there is nothing to point at"
    /// the same answer as "there is no real item".
    var anchorButton: NSStatusBarButton? { item.button }

    private func render() {
        guard let button = item.button else { return }
        // Lightness is the whole starting signal: the menu bar
        // tints template images itself, so a hue would not
        // survive it — and would be the one channel colour-vision
        // deficiency takes away. `appearsDisabled` is AppKit's own
        // dimming, and the mark returning to full strength IS the
        // ready signal (#802). Assigned unconditionally, so every
        // other branch below clears it.
        button.appearsDisabled = starting
        if warning {
            // Permission failure keeps the loud triangle; config
            // error uses a distinct, softer circle so the two are
            // never confused in the always-on glyph (§3.7).
            setStatusSymbol(
                "exclamationmark.triangle.fill",
                on: button,
                a11y: L(
                    "menu.status.warning.a11y",
                    "KiwiDesk (permission required)"
                ),
                tooltip: L(
                    "menu.status.warning.tooltip",
                    "KiwiDesk needs Accessibility permission. "
                        + "Window management is paused."
                )
            )
            return
        }
        if starting {
            button.toolTip = L(
                "menu.status.starting.tooltip",
                "KiwiDesk is starting up — going through your "
                    + "open apps."
            )
            applyBrandIcon(
                to: button,
                a11y: L(
                    "menu.status.starting.a11y",
                    "KiwiDesk (starting up)"
                )
            )
            return
        }
        if configError {
            setStatusSymbol(
                "exclamationmark.circle.fill",
                on: button,
                a11y: L(
                    "menu.status.config_error.a11y",
                    "KiwiDesk (config issues)"
                ),
                tooltip: L(
                    "menu.status.config_error.tooltip",
                    "Parts of the configuration could not be "
                        + "loaded — open %1$@ for details.",
                    L("config_issues.title", "Config Issues")
                )
            )
            return
        }
        button.toolTip = L("menu.status.tooltip", "KiwiDesk")
        if let modeIcon, !modeIcon.isEmpty {
            applyModeIcon(modeIcon, to: button)
        } else {
            applyBrandIcon(
                to: button,
                a11y: L("menu.status.a11y", "KiwiDesk")
            )
        }
    }

    /// The standard kiwi mark, named for VoiceOver by the caller
    /// — the starting state and the ready one draw the SAME
    /// glyph, so the name is the only thing that separates them
    /// to a reader who cannot see the dimming. The label goes on
    /// the BUTTON rather than the image: `BrandAssets.menuBarIcon`
    /// is a shared cached `NSImage`, and re-describing it would
    /// rename it for every other surface that draws it.
    private func applyBrandIcon(
        to button: NSStatusBarButton,
        a11y: String
    ) {
        button.setAccessibilityLabel(a11y)
        if let icon = BrandAssets.menuBarIcon
            ?? symbol("rectangle.3.group")
        {
            button.image = icon
            button.title = ""
        } else {
            // Last-ditch: never leave the slot blank.
            button.image = nil
            button.title = a11y
        }
    }

    /// Sets the status button to the SF Symbol `name`, or — if
    /// that symbol doesn't resolve on this macOS version — a
    /// visible text fallback, so the menu bar item is never blank.
    /// A nil image with an empty title leaves an
    /// invisible-but-clickable slot that reads as a broken app
    /// (an invalid symbol name — `doc.badge.exclamationmark`,
    /// which does not exist — once did exactly that).
    private func setStatusSymbol(
        _ name: String,
        on button: NSStatusBarButton,
        a11y: String,
        tooltip: String
    ) {
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: a11y
        )
        image?.isTemplate = true
        button.image = image
        button.title = image == nil ? "⚠︎" : ""
        button.toolTip = tooltip
        // Same reason as `applyBrandIcon`: name the button, not
        // the image, so every state announces itself even when
        // the text fallback is what rendered.
        button.setAccessibilityLabel(a11y)
    }

    /// A mode icon is either an SF Symbol name or a flat
    /// emoji; emoji fall back to the button title when no
    /// symbol matches.
    ///
    /// It names the button like every other render path, and that
    /// is load-bearing rather than tidy: an accessibility label on
    /// an `NSView` PERSISTS until something replaces it, so the
    /// one path that set none inherited whatever the last one said
    /// — switch layers after boot and the mark still announced
    /// "KiwiDesk (starting up)", on a healthy app, indefinitely
    /// (localization audit, 2026-08-12). Once one path names the
    /// button, every path owes a name.
    ///
    /// The name is the app's, not the layer's: the icon string is
    /// an SF Symbol identifier or a bare emoji from the user's Lua
    /// config, and announcing `star.fill` would be worse than
    /// announcing nothing. Naming the active LAYER needs the
    /// layer's name at this seam, which is #TBD rather than this
    /// change set.
    private func applyModeIcon(
        _ icon: String,
        to button: NSStatusBarButton
    ) {
        button.setAccessibilityLabel(L("menu.status.a11y", "KiwiDesk"))
        if let image = NSImage(
            systemSymbolName: icon,
            accessibilityDescription: icon
        ) {
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = icon
        }
    }

    /// Shared SF Symbol → template-image helper for the menu
    /// builders (`+Menu`, `+Layout`) and `render`.
    func symbol(_ name: String) -> NSImage? {
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )
        image?.isTemplate = true
        return image
    }

}

// MARK: - The live slot

/// The real menu-bar slot: registers a visible item with the
/// system bar for the life of the process — right for the app,
/// wrong for a test process. No removal on deinit,
/// deliberately: the controller is app-lifetime, and `deinit`
/// is nonisolated where `NSStatusBar` is main-actor.
///
/// File-scoped `private` IS the seal — tests cannot name this
/// type, so a live item cannot be passed through the seam; do
/// not raise its access (`StatusItemSeamGuardTests` pins the
/// declaration). The seam's story lives at `StatusItemHandle`.
@MainActor
private final class SystemStatusItem: StatusItemHandle {
    private let item: NSStatusItem

    init() {
        item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
    }

    var button: NSStatusBarButton? { item.button }

    var menu: NSMenu? {
        get { item.menu }
        set { item.menu = newValue }
    }
}
