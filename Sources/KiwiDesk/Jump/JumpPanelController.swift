import AppKit
import KiwiDeskCore
import SwiftUI
import os

/// Diagnostic logging for the panel's show, pick and close.
/// `privacy: .public`, or macOS redacts every line (#951).
let jumpLog = Logger(
    subsystem: KiwiLog.subsystem,
    category: "gui"
)

/// The key panel (#1875, #2229, #2246): the window switcher, the
/// shortcuts sheet and the view picker, one panel at Spotlight's
/// height on the screen under the pointer, opened over a snapshot
/// of every window KiwiDesk knows.
/// A pick closes it and hands the row to Core's `jump(to:)`,
/// `moveHere(_:)` or `swapHere(_:)`; Esc, ⌘W and a click away
/// close it.
@MainActor
final class JumpPanelController: NSObject, NSWindowDelegate {
    let core: KiwiCore
    /// The keyed show and the close's dismiss distrust (#952).
    let handBack: PanelHandBack
    var panel: JumpPanel?
    private(set) var currentModel: JumpModel?
    /// Opens Settings on Shortcuts, set by the app.
    var onEditShortcuts: () -> Void = {}
    /// This opening; a fade a later show overtook orders nothing
    /// out.
    private var presence = PanelPresence()
    /// The bus sink a stay-open drop reads the desk through (#3208).
    var landingSink: UUID?
    /// Seam for Reduce Motion, macOS's or KiwiDesk's own (#565,
    /// #3238).
    var reduceMotion: @MainActor () -> Bool = { ReduceMotion.isOn }

    init(core: KiwiCore) {
        self.core = core
        handBack = PanelHandBack(core: core)
        super.init()
    }

    /// Up and not leaving: a toggle during the exit fade opens a
    /// new panel rather than closing one already going.
    var isOpen: Bool { panel?.isVisible == true && !presence.leaving }

    /// Why window management is held (#2050), if it is; the View
    /// side greys its chips meanwhile (#2309 ruling 9).
    var hold: () -> CoreHold = { .running }
    /// The Space the View side's Layout line acts on, read with the screen
    /// the panel opens on so the two never disagree.
    var pickerSpace: SpaceID?
    /// The screen the panel opened on: its list's "here" and Move
    /// here's target are the Space it shows (#2791).
    private(set) var hubDisplay: DisplayID?

    /// A scope's own shortcut (#2229).
    func toggle(_ scope: JumpScope = .windows) {
        switch Self.toggleAction(
            showing: isOpen ? currentModel?.scope : nil,
            asked: scope
        ) {
        case .open: show(scope)
        case .close: close()
        case .switchScope:
            currentModel?.setScope(scope)
            currentModel?.latchOpener(NSEvent.modifierFlags)
        }
    }

    enum ToggleAction: Equatable { case open, close, switchScope }

    /// Closes the panel where it already shows the asked scope,
    /// switches where it shows the other, else opens on it.
    static func toggleAction(
        showing: JumpScope?,
        asked: JumpScope
    ) -> ToggleAction {
        guard let showing else { return .open }
        return showing == asked ? .close : .switchScope
    }

    /// `lastApp` puts the Windows side's strip on the app of the
    /// window used last (#3135).
    func show(_ scope: JumpScope = .windows, lastApp: Bool = false) {
        let screen = PanelHandBack.screenUnderPointer()
        pickerSpace = core.layoutPickerSpace()
        hubDisplay = core.jumpDisplay()
        let visible =
            screen?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let area = Self.clearArea(
            visible: visible,
            shelves: core.shelfFrames()
        )
        let snapshot = core.jumpSnapshot(on: hubDisplay)
        let width = Self.width(visibleWidth: area.width)
        let model = JumpModel(
            snapshot: snapshot,
            icons: Self.icons(for: snapshot),
            rowCap: Self.rowCap,
            sheetCap: Self.sheetCap(visible: visible, area: area),
            panelWidth: width,
            modifiers: NSEvent.modifierFlags
        )
        // The chord that opened the panel is still held (#3168).
        model.latchOpener(NSEvent.modifierFlags)
        model.chords = liveChords()
        model.lastAppChord = lastAppChord()
        model.settings = core.tiler.settings
        let panel = self.panel ?? makePanel()
        self.panel = panel
        self.currentModel = model
        let presence = PanelPresence()
        self.presence = presence
        wire(model, panel)
        if scope != .windows { model.setScope(scope) }
        if lastApp { model.openOnLastApp() }
        let root = JumpPanelView(
            model: model,
            presence: presence,
            width: width
        )
        let hosting = NSHostingView(
            rootView: LocaleScopedRoot { root }
                .environmentObject(LocalizationManager.shared)
        )
        // A field editor left by the last opening would keep the
        // keys from the new content's field.
        panel.makeFirstResponder(nil)
        // A close's unseen hold may still be under way (#3209).
        panel.alphaValue = 1
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        if screen != nil {
            panel.setFrameOrigin(
                Self.origin(
                    size: panel.frame.size,
                    visible: visible,
                    area: area
                )
            )
        } else {
            panel.center()
        }
        let front = PanelHandBack.frontmostBundleID()
        let rows = snapshot.entries.count
        jumpLog.log(
            "KiwiDesk: jump show; \(rows, privacy: .public) rows"
        )
        jumpLog.log("KiwiDesk: jump front \(front, privacy: .public)")
        handBack.present(panel) { [weak self, presence] in
            self?.presence === presence && !presence.leaving
        }
    }

    /// Repaints the shown panel on a settings change by any door,
    /// as the bars repaint (#2604); a closed one keeps its model.
    func settingsChanged(_ settings: TilingSettings) {
        guard !presence.leaving else { return }
        currentModel?.settings = settings
    }

    /// Closes the panel. No close arms the dismiss distrust: the
    /// panels are non-activating, so the window a close keys again
    /// is the one the user was in (owner ruling 2026-10-13).
    func close() {
        dismiss(distrusting: false)
    }

    /// Closes on a pick, then runs it — once: a click during the
    /// exit fade picks nothing.
    func pick(_ entry: JumpEntry, _ pick: JumpPick) {
        guard
            dismiss(
                distrusting: Self.distrustsHandoff(
                    pick: entry.pid,
                    own: ProcessInfo.processInfo.processIdentifier
                )
            )
        else { return }
        let named = String(describing: pick)
        jumpLog.log("KiwiDesk: jump pick \(named, privacy: .public)")
        switch pick {
        case .jump: core.jump(to: entry.target)
        case .moveHere: core.moveHere(entry.target, on: hubDisplay)
        // After the dismiss, so the swap verb's #292 preflight reads
        // the app the panel handed back.
        case .swapHere: core.swapHere(entry.target, on: hubDisplay)
        }
    }

    /// Whether a pick arms the own-window handoff distrust: never
    /// for our own window, whose focus report the distrust eats.
    static func distrustsHandoff(pick pid: pid_t, own: pid_t) -> Bool {
        pid != own
    }

    /// The one close; false where there is nothing to close. A
    /// close already fading refuses the resign-key it fires, and a
    /// panel already hidden has no blip to distrust.
    @discardableResult
    func dismiss(distrusting: Bool) -> Bool {
        guard panel?.isVisible != false, !presence.leaving else {
            return false
        }
        let hold = PanelPresence.clickHoldNow(on: panel)
        handBack.release(distrusting: distrusting) { [weak self] in
            self?.fadeOut(holdUnseen: hold)
        }
        return true
    }

    /// Fades the panel out, then orders it out; it stops taking
    /// keys and clicks the moment the fade starts.
    private func fadeOut(holdUnseen: TimeInterval) {
        endLanding()
        currentModel?.leave()
        presence.fadeOut(
            panel,
            reduceMotion: reduceMotion(),
            holdUnseen: holdUnseen
        ) { [weak self] in self?.presence === $0 }
    }

    // MARK: - Construction

    /// Internal so `MainMenuTests` takes the production panel.
    func makePanel() -> JumpPanel {
        let panel = JumpPanel(
            contentRect: .zero,
            styleMask: [
                .borderless, .fullSizeContentView, .nonactivatingPanel,
            ],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        // Core holds every tap but a side's own while KiwiHub is
        // key, telling it by this stamp (#1229).
        panel.identifier = NSUserInterfaceItemIdentifier(
            KiwiHubSide.panelIdentifier
        )
        panel.isReleasedWhenClosed = false
        // A deactivation hide would leave the panel to come back
        // with the next activation; the resign-key close owns it.
        panel.hidesOnDeactivate = false
        // The view animates its own entrance and exit.
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary,
        ]
        panel.delegate = self
        panel.keys = { [core] in core.appWide.kiwiHubKeys }
        // Back follows the opener's live chord, never a fixed one.
        panel.back = { [core] in Self.backKey(core) }
        panel.onCancel = { [weak self] in
            self?.close()
        }
        panel.leaving = { [weak self] in self?.presence.leaving ?? false }
        return panel
    }

    private func wire(_ model: JumpModel, _ panel: JumpPanel) {
        panel.onKey = { [weak model] in
            model?.handle($0, repeated: $1)
        }
        panel.onModifiers = { [weak model] in
            model?.noteModifiers($0)
        }
        panel.pickModifiers = { [weak model] in
            model?.pickModifiers($0) ?? $0
        }
        panel.onBackChord = { [weak model] in model?.latchOpener($0) }
        model.onPick = { [weak self] entry, pick in
            self?.pick(entry, pick)
        }
        // A refusal the panel already shows stays in the panel: a
        // beep where Refusal sound is on, and VoiceOver's words.
        model.onRefuse = { [weak self, weak model] spoken in
            self?.core.soundPanelRefusal()
            model?.onAnnounce(spoken)
        }
        // A ↩ chord that picks nothing: the system beep, never
        // the refusal sound (#2931 ▸ Ruling 4).
        model.onDeadKey = { NSSound.beep() }
        // Core answers at the press, from the panel's screen.
        model.swapRefusal = { [weak self] entry in
            self?.core.swapRefusal(entry.target, on: self?.hubDisplay)
        }
        model.moveRefusal = { [weak self] entry in
            self?.core.moveHereRefusal(entry.target, on: self?.hubDisplay)
        }
        model.onClose = { [weak self] in
            self?.close()
        }
        model.onAnnounce = { [weak panel] text in
            guard let panel else { return }
            NSAccessibility.post(
                element: panel,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: text,
                    .priority:
                        NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
        // The next turn: the hosting view has not re-laid the new
        // results out in the setter's own.
        model.onResultsChange = { [weak self] in
            DispatchQueue.main.async { self?.refit() }
        }
        model.onStripToggle = { [weak self] in
            DispatchQueue.main.async { self?.refit(animated: true) }
        }
        // After the outgoing scope's fade: until it ends, the
        // stack still lays that scope out.
        model.onScopeChange = { [weak self] in
            guard let self else { return }
            let delay =
                self.reduceMotion() ? 0 : JumpPanelView.scopeFade + 0.02
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.refit(animated: true)
            }
        }
        panel.scope = { [weak model] in model?.scope ?? .windows }
        panel.naming = { [weak model] in model?.isNaming ?? false }
        wireView(model)
        wireDesktops(model)
        wireShortcuts(model)
    }

    // MARK: - NSWindowDelegate

    /// The field takes the keys whenever the panel does.
    func windowDidBecomeKey(_ notification: Notification) {
        currentModel?.requestFieldFocus()
    }

    func windowDidResignKey(_ notification: Notification) {
        jumpLog.log("KiwiDesk: jump resign key; open \(self.isOpen)")
        close()
    }
}
