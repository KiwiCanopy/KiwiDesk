import AppKit
import KiwiDeskCore
import SwiftUI

/// The look picker on `⌃⌥⇧L` (#3038): a full-screen key panel on the
/// focused screen, opened and closed by `look.show_picker()`. ↩ wears
/// a look for good through Core's one door, under the opaque overlay,
/// then the puddle opens the desk; Esc and the shortcut close and
/// never undo.
@MainActor
final class LookPickerController: NSObject {
    let core: KiwiCore
    let handBack: PanelHandBack
    private(set) var panel: LookPickerPanel?
    private(set) var model: LookPickerModel?
    private(set) var reveal = LookPickerReveal()
    /// This opening's drop, above the picker (#3700); nil once the
    /// panel lets its content go.
    var dropView: LookPickerDropView? {
        (panel?.contentView as? LookPickerContent)?.drop
    }
    /// This opening; a timer an earlier opening set finds another.
    var opening = 0
    var revealing = false
    /// The running wear's frame count, logged at the close (#3700).
    var frameLog: LookPickerFrameLog?
    /// Seam for KiwiDesk's Reduce Motion (#3252), read once per
    /// opening and handed to the view.
    var reduceMotion: () -> Bool = { ReduceMotion.isOn }
    var reduceMotionNow = false
    /// Where this opening draws, which the wave starts from.
    var geometry = LookPickerGeometry(screen: .zero, menuBar: 0)
    /// Seam deferring work by a delay on the main queue.
    var after: (TimeInterval, @escaping @MainActor () -> Void) -> Void = {
        delay,
        work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            MainActor.assumeIsolated(work)
        }
    }

    /// Seam running work once the current transaction has
    /// committed (#3700).
    var afterCommit: (@escaping @MainActor () -> Void) -> Void = { work in
        CATransaction.setCompletionBlock {
            MainActor.assumeIsolated(work)
        }
    }

    /// Seam for how long a click's close holds the panel (#3209).
    var clickHold: (NSWindow?) -> TimeInterval = {
        PanelPresence.clickHoldNow(on: $0)
    }

    /// How long the reveal waits for Core's "desk ready" at most:
    /// #3478's wallpaper confirmation (#3038 ▸ Ruling, step 1).
    static let readyCap: TimeInterval = 0.4

    init(core: KiwiCore) {
        self.core = core
        handBack = PanelHandBack(core: core)
        super.init()
    }

    /// Up and not closing: a panel held for a click (#3209) is
    /// already closed, so the shortcut opens it again.
    var isOpen: Bool { model != nil && panel?.isVisible == true }

    /// The shortcut: opens the picker, or closes it, never undoing.
    func toggle() {
        isOpen ? close() : show()
    }

    func show() {
        guard
            let screen = core.lookPickerScreen()
                ?? PanelHandBack.screenUnderPointer()
        else { return }
        opening += 1
        revealing = false
        _ = frameLog?.stop()
        frameLog = nil
        reduceMotionNow = reduceMotion()
        let model = makeModel(on: screen)
        let reveal = LookPickerReveal()
        self.model = model
        self.reveal = reveal
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let geometry = LookPickerGeometry(
            screen: screen.frame.size,
            menuBar: max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        )
        self.geometry = geometry
        let root = LookPickerView(
            model: model,
            reveal: reveal,
            geometry: geometry
        )
        .environment(\.kiwiDeskReduceMotion, reduceMotionNow)
        panel.makeFirstResponder(nil)
        panel.alphaValue = 1
        panel.contentView = LookPickerContent(
            picker: NSHostingView(
                rootView: LocaleScopedRoot { root }
                    .environmentObject(LocalizationManager.shared)
            ),
            drop: LookPickerDropView(frame: .zero)
        )
        panel.setFrame(screen.frame, display: true)
        let current = opening
        handBack.present(panel) { [weak self] in
            self?.opening == current
        }
        if let spoken = model.spokenSelection { announce(spoken) }
    }

    /// Repaints the cards on a settings change by any door (#2604),
    /// save the wear's own write: under the overlay it would re-render
    /// every card as the drop starts to fall (#3700).
    func settingsChanged(_ settings: TilingSettings) {
        guard model?.phase == .browsing else { return }
        model?.settings = settings
    }

    /// Closes at once, the puddle included; nothing is undone. A
    /// click that closed it holds the panel up unseen for the rest
    /// of the double-click interval, so a second press lands on it
    /// (#3209).
    func close() {
        if let line = frameLog?.stop() { core.onLog(line) }
        frameLog = nil
        let hold = clickHold(panel)
        opening += 1
        revealing = false
        model = nil
        guard let panel else { return }
        guard hold > 0 else { return Self.orderOut(panel) }
        panel.alphaValue = PanelPresence.holdAlpha
        let current = opening
        after(hold) { [weak self, weak panel] in
            guard self?.opening == current, let panel else { return }
            Self.orderOut(panel)
        }
    }

    private static func orderOut(_ panel: NSPanel) {
        panel.orderOut(nil)
        panel.contentView = nil
        panel.alphaValue = 1
    }

    // MARK: - Cards

    private func makeModel(on screen: NSScreen) -> LookPickerModel {
        let current = core.unsavedWornLook()
        let entries = LookPickerEntry.cards(
            current: current,
            bundled: core.bundledLooks,
            saved: core.userLooks
        )
        let worn =
            current != nil
            ? 0 : Self.wornIndex(of: core.wornLibraryLook, in: entries)
        let model = LookPickerModel(
            cards: entries,
            worn: worn,
            settings: core.tiler.settings,
            spaceLabels: BarsPanelPreview.spaceLabels(
                of: core.loadGuiConfig()
            ),
            pictures: LookPickerPictures(
                library: core.wallpaperLibrary,
                maxPixels: Int(
                    max(screen.frame.width, screen.frame.height)
                        * screen.backingScaleFactor
                ),
                screen: core.screenNumber(of: screen)
            )
        )
        wire(model)
        return model
    }

    /// The card whose look the desk wears, by kind and name.
    static func wornIndex(
        of worn: ShelfLook?,
        in entries: [LookPickerEntry]
    ) -> Int? {
        guard let worn else { return nil }
        return entries.firstIndex {
            $0.kind != .current && $0.look.name == worn.name
        }
    }

    private func wire(_ model: LookPickerModel) {
        model.onClose = { [weak self] in self?.close() }
        model.onDeadKey = { NSSound.beep() }
        model.onAnnounce = { [weak self] in self?.announce($0) }
        model.onWear = { [weak self] in self?.wear($0) }
        model.onQuickSave = { [weak self] in self?.quickSave() }
        model.onRename = { [weak self] from, to in
            try? self?.core.renamePickedLook(from: from, to: to)
        }
    }

    private func quickSave() -> ShelfLook? {
        let focus = core.tiler.settings.borderStyle.focusedColor
        let name = LookQuickName.name(focusHex: focus, on: Date())
        return try? core.saveWornLook(base: name)
    }

    // MARK: - Panel

    func makePanel() -> LookPickerPanel {
        let panel = LookPickerPanel(
            contentRect: .zero,
            styleMask: [
                .borderless, .fullSizeContentView, .nonactivatingPanel,
            ],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Over the bars, which the picker covers with the screen.
        panel.level = BarPanel.aboveLevel
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.onKey = { [weak self] key, repeated in
            self?.model?.handle(key, repeated: repeated)
        }
        panel.naming = { [weak self] in self?.model?.isNaming ?? false }
        panel.revealing = { [weak self] in self?.revealing ?? false }
        panel.onInterrupt = { [weak self] in self?.close() }
        panel.onClose = { [weak self] in self?.close() }
        return panel
    }

    func announce(_ text: String) {
        guard let panel else { return }
        NSAccessibility.post(
            element: panel,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}

/// Losing the keyboard closes the picker, as KiwiHub (#1875).
extension LookPickerController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
