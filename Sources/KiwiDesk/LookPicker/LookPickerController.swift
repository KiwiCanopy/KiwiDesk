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
    /// This opening; a timer an earlier opening set finds another.
    private var opening = 0
    private var revealing = false
    /// Seam for KiwiDesk's Reduce Motion (#3252), read once per
    /// opening and handed to the view.
    var reduceMotion: () -> Bool = { ReduceMotion.isOn }
    private var reduceMotionNow = false
    /// Where this opening draws, which the wave starts from.
    private var geometry = LookPickerGeometry(screen: .zero, menuBar: 0)
    /// Seam deferring work by a delay on the main queue.
    var after: (TimeInterval, @escaping @MainActor () -> Void) -> Void = {
        delay,
        work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            MainActor.assumeIsolated(work)
        }
    }

    /// How long the reveal waits for Core's "desk ready" at most:
    /// #3478's wallpaper confirmation (#3038 ▸ Ruling, step 1).
    static let readyCap: TimeInterval = 0.4

    init(core: KiwiCore) {
        self.core = core
        handBack = PanelHandBack(core: core)
        super.init()
    }

    var isOpen: Bool { panel?.isVisible == true }

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
        reduceMotionNow = reduceMotion()
        let model = makeModel()
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
        panel.contentView = NSHostingView(
            rootView: LocaleScopedRoot { root }
                .environmentObject(LocalizationManager.shared)
        )
        panel.setFrame(screen.frame, display: true)
        let current = opening
        handBack.present(panel) { [weak self] in
            self?.opening == current
        }
        if let spoken = model.spokenSelection { announce(spoken) }
    }

    /// Repaints the cards on a settings change by any door (#2604).
    func settingsChanged(_ settings: TilingSettings) {
        guard !revealing else { return }
        model?.settings = settings
    }

    /// Closes at once, the puddle included; nothing is undone.
    func close() {
        opening += 1
        revealing = false
        panel?.orderOut(nil)
        panel?.contentView = nil
        model = nil
    }

    // MARK: - Cards

    private func makeModel() -> LookPickerModel {
        let current = core.unsavedWornLook(named: "")
        let entries = LookPickerEntry.cards(
            current: current,
            bundled: core.bundledLooks,
            saved: core.userLooks
        )
        let worn =
            current != nil
            ? 0 : Self.wornIndex(of: core.wornLibraryLook, in: entries)
        let model = LookPickerModel(
            entries: entries,
            worn: worn,
            settings: core.tiler.settings,
            spaceLabels: BarsPanelPreview.spaceLabels(of: core.loadGuiConfig())
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
            guard let self else { return nil }
            do {
                try core.renameLook(from: from, to: to)
                return LibraryNameVerdict.normalized(to)
            } catch {
                return nil
            }
        }
    }

    private func quickSave() -> ShelfLook? {
        let focus = core.tiler.settings.borderStyle.focusedColor
        let name = LookQuickName.name(focusHex: focus, on: Date())
        return try? core.saveWornLook(base: name)
    }

    // MARK: - Wear and reveal

    /// ↩ on a look not worn: Core wears it with the windows placed at
    /// once, then the reveal waits for the desk — at most
    /// `readyCap` — whichever comes first.
    private func wear(_ entry: LookPickerEntry) {
        let current = opening
        let latch = ResumeLatch()
        let resume: @MainActor () -> Void = { [weak self] in
            guard !latch.fired, let self, opening == current else { return }
            latch.fired = true
            startReveal()
        }
        announce(LookPickerText.wearing(entry.look.name))
        core.wearPickedLook(entry.look, ready: resume)
        after(Self.readyCap, resume)
    }

    private func startReveal() {
        guard panel != nil else { return }
        revealing = true
        let reveal = self.reveal
        let current = opening
        let reduceMotion = reduceMotionNow
        let finish: @MainActor () -> Void = { [weak self] in
            guard let self, opening == current else { return }
            close()
        }
        if reduceMotion {
            withAnimation(Self.crossFade(reduceMotion: reduceMotion)) {
                reveal.opacity = 0
            }
            after(LookPickerReveal.crossFade, finish)
            return
        }
        reveal.dropShown = true
        withAnimation(
            reduceMotion ? nil : .easeIn(duration: LookPickerReveal.fall)
        ) {
            reveal.dropLanded = true
        }
        let reach = Self.reach(of: geometry)
        after(LookPickerReveal.fall) { [weak self] in
            guard self?.opening == current else { return }
            withAnimation(
                reduceMotion
                    ? nil : .easeOut(duration: LookPickerReveal.splash)
            ) {
                reveal.dropSplashed = true
            }
            withAnimation(
                reduceMotion
                    ? nil : .easeOut(duration: LookPickerReveal.blurIn)
            ) {
                reveal.blur = LookPickerReveal.blurRadius
            }
            reveal.waveShown = true
            withAnimation(
                reduceMotion ? nil : .easeOut(duration: LookPickerReveal.wave)
            ) {
                reveal.holeRadius = reach
            }
            self?.after(LookPickerReveal.wave, finish)
        }
    }

    /// Reduce Motion's 0.2 s cross-fade, a fade and no travel; it
    /// plays only for a Reduce Motion user, whom the puddle skips.
    static func crossFade(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeInOut(duration: LookPickerReveal.crossFade) : nil
    }

    /// How far the wave travels: past the corner farthest from the
    /// card's centre, its band included.
    static func reach(of geometry: LookPickerGeometry) -> CGFloat {
        let size = geometry.screen
        let centre = CGPoint(x: geometry.card.midX, y: geometry.card.midY)
        let corners = [
            CGPoint.zero, CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height),
        ]
        let far =
            corners.map { hypot($0.x - centre.x, $0.y - centre.y) }
            .max() ?? 0
        return far + LookPickerReveal.band
    }

    // MARK: - Panel

    private func makePanel() -> LookPickerPanel {
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

    private func announce(_ text: String) {
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

/// Resumes the reveal once: Core's `ready` or the cap, first wins.
@MainActor
private final class ResumeLatch {
    var fired = false
}
