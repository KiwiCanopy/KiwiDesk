import AppKit
import CoreGraphics

/// Visual plate and overlay panel for minimum-size refusal pill
/// (#933). One panel PER window: a blocked grow pills BOTH ends —
/// the resized window and the blocking one — so two pills must be
/// able to stand at once (owner ruling 2026-08-22).
@MainActor
final class SizeLimitOverlay {
    private struct Pill {
        let panel: NSPanel
        let plate: SizeLimitPillPlate
        var hideWork: DispatchWorkItem?
    }

    private var pills: [CGWindowID: Pill] = [:]

    /// AppKit keeps a visible panel alive after its owner is gone,
    /// so a dropped overlay would leave it on screen (#1868).
    isolated deinit {
        for pill in pills.values {
            pill.hideWork?.cancel()
            pill.panel.orderOut(nil)
        }
    }

    private static let holdDuration: TimeInterval = 1.4
    private static let fadeDuration: TimeInterval = 0.2
    private static let pillHeight: CGFloat = 26
    nonisolated static let pillPadding: CGFloat = 20
    /// The entrance pop's keyframe scales. Its PEAK sizes the
    /// panel's margin (`PopRoom`), so a retune cannot clip the
    /// pill's ends at the window edge again (#2033).
    nonisolated static let popKeyframes: [(scale: CGFloat, time: Double)] =
        [(0.95, 0), (1.03, 0.5), (1.0, 1.0)]

    init() {}

    /// The pill's drawn width for a window of `frame` carrying
    /// text of `textWidth`, or nil where the window is too
    /// narrow to draw one at all.
    ///
    /// Pure and `static` so the decline is checkable without a
    /// screen (`SizeLimitPillWidthTests`): the caller sounds on
    /// what this reports, so a decline invisible to a test is a
    /// refusal that beeps at nothing (#1255, ui-designer
    /// 2026-09-05).
    nonisolated static func pillWidth(
        frame: CGRect,
        textWidth: CGFloat
    ) -> CGFloat? {
        let width = min(
            frame.width - 24,
            max(textWidth + pillPadding, 120)
        )
        return width > 40 ? width : nil
    }

    /// Flashes size-limit pill on window frame in AX coordinates
    /// (#933). Returns whether one actually appeared — the
    /// caller's refusal sound follows this, never the fact that
    /// it asked (#1255).
    @discardableResult
    func flash(
        window: CGWindowID,
        frame: CGRect,
        text: String,
        symbol: String
    ) -> Bool {
        present(window: window, frame: frame, text: text, symbol: symbol)
    }

    /// Shows a lens's reminder pill centred on a held window, with
    /// no symbol and no timer: it stays until `release` (#2103
    /// ruling 12). A pill already shown follows the window without
    /// popping again.
    @discardableResult
    func hold(window: CGWindowID, frame: CGRect, text: String) -> Bool {
        present(window: window, frame: frame, text: text, symbol: nil)
    }

    /// Fades a pill out now, a held one included.
    func release(_ window: CGWindowID) {
        guard let pill = pills[window] else { return }
        pill.hideWork?.cancel()
        pills[window]?.hideWork = nil
        fadeOut(window)
    }

    /// Shows the pill: a refusal's at the window's top with its
    /// symbol, faded after `holdDuration`; a hold's centred, with
    /// no symbol, until released.
    private func present(
        window: CGWindowID,
        frame: CGRect,
        text: String,
        symbol: String?
    ) -> Bool {
        let shown = pills[window] != nil
        var pill = pills[window] ?? makePill()
        pill.hideWork?.cancel()
        pill.hideWork = nil

        pill.plate.setText(text)
        pill.plate.setSymbol(symbol)
        let textSize = pill.plate.fittingSize
        // The hide timer was already cancelled above, so a bare
        // return here would strand a showing pill at alpha 1
        // forever — fade it out instead of leaving it.
        guard
            let pillWidth = Self.pillWidth(
                frame: frame,
                textWidth: textSize.width
            )
        else {
            pills[window] = pill
            fadeOut(window)
            return false
        }

        let pillRect = CGRect(
            x: frame.midX - pillWidth / 2,
            y: symbol == nil
                ? frame.midY - Self.pillHeight / 2 : frame.minY + 8,
            width: pillWidth,
            height: Self.pillHeight
        )
        let screenRect = GeometryUtils.flip(
            pillRect,
            primaryHeight: GeometryUtils.primaryHeight
        )
        let panelRect = PopRoom.panelFrame(
            for: screenRect,
            scales: Self.popKeyframes.map(\.scale)
        )

        if symbol == nil, shown, pill.panel.frame == panelRect {
            return true
        }
        // The plate first: the shadow follows what the panel draws.
        pill.plate.frame = PopRoom.plateFrame(
            plate: screenRect,
            in: panelRect
        )
        pill.panel.setFrame(panelRect, display: true)
        pill.panel.invalidateShadow()
        pill.panel.order(.above, relativeTo: Int(window))
        pill.panel.alphaValue = 1

        if symbol != nil || !shown,
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        {
            popEntrance(pill.plate)
        }

        pills[window] = pill
        guard symbol != nil else { return true }
        let work = DispatchWorkItem { [weak self] in
            self?.fadeOut(window)
        }
        pill.hideWork = work
        pills[window] = pill
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.holdDuration,
            execute: work
        )
        return true
    }

    private func fadeOut(_ window: CGWindowID) {
        guard let pill = pills[window], pill.panel.isVisible
        else {
            retire(window)
            return
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            pill.panel.orderOut(nil)
            retire(window)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            pill.panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // AppKit calls the completion on the main thread;
            // the closure is typed `@Sendable`, so hop back
            // into the actor explicitly.
            MainActor.assumeIsolated {
                guard let self else { return }
                // A re-flash between fade start and completion
                // re-armed the timer; only a pill still fading
                // retires (ids churn, the map must not grow for
                // the session).
                if let pill = self.pills[window],
                    pill.panel.alphaValue == 0
                {
                    pill.panel.orderOut(nil)
                    self.retire(window)
                }
            }
        }
    }

    /// Closes and forgets a window's pill; ids are reused, so
    /// the map holds only pills currently showing or fading.
    private func retire(_ window: CGWindowID) {
        guard let pill = pills.removeValue(forKey: window)
        else { return }
        pill.hideWork?.cancel()
        pill.panel.close()
    }

    private func popEntrance(_ plate: SizeLimitPillPlate) {
        guard let layer = plate.layer else { return }
        let pop = CAKeyframeAnimation(keyPath: "transform")
        // The view's own size: the layer's may not be laid out yet.
        pop.values = Self.popKeyframes.map {
            NSValue(
                caTransform3D: PopRoom.transform(
                    scale: $0.scale,
                    size: plate.bounds.size,
                    anchor: layer.anchorPoint
                )
            )
        }
        pop.keyTimes = Self.popKeyframes.map { NSNumber(value: $0.time) }
        pop.duration = 0.14
        // One per segment: out while growing, in while settling.
        let scales = Self.popKeyframes.map(\.scale)
        pop.timingFunctions = zip(scales, scales.dropFirst()).map {
            CAMediaTimingFunction(name: $1 > $0 ? .easeOut : .easeIn)
        }
        layer.add(pop, forKey: "entrancePop")
    }

    private func makePill() -> Pill {
        let plate = SizeLimitPillPlate()
        return Pill(
            panel: makePanel(plate),
            plate: plate,
            hideWork: nil
        )
    }

    #if DEBUG
        /// Test-only: a shown pill's panel frame and its plate,
        /// as `flash` placed them.
        func pillForTest(
            _ window: CGWindowID
        ) -> (panel: CGRect, content: NSView?, plate: NSView)? {
            pills[window].map {
                ($0.panel.frame, $0.panel.contentView, $0.plate)
            }
        }
    #endif

    private func makePanel(
        _ plate: SizeLimitPillPlate
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .transient,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        // A clear host with the plate inside it, so the pop grows
        // into the margin rather than past the window (#2033).
        let host = NSView()
        host.addSubview(plate)
        panel.contentView = host
        return panel
    }

}
