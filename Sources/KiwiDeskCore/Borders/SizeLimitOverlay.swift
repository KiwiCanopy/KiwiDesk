import AppKit
import CoreGraphics

/// Visual plate and panel for the minimum-size refusal pill (#933).
///
/// Flashed at the top-center of a window when a resize attempt
/// runs into an effective minimum size (`min_window_size` or an
/// app-enforced `EffectiveSizeBound`). Holds one panel PER
/// window: a blocked grow pills BOTH ends — the resized window
/// explains why nothing moved, the blocking window marks itself
/// at its minimum — so two pills must be able to stand at once
/// (owner ruling, 2026-08-22).
@MainActor
final class SizeLimitOverlay {
    private struct Pill {
        let panel: NSPanel
        let plate: SizeLimitPillPlate
        var hideWork: DispatchWorkItem?
    }

    private var pills: [CGWindowID: Pill] = [:]

    private static let holdDuration: TimeInterval = 1.4
    private static let fadeDuration: TimeInterval = 0.2
    private static let pillHeight: CGFloat = 26
    private static let pillPadding: CGFloat = 20

    init() {}

    /// Flashes the size-limit pill on `window` at `frame` (AX coordinates).
    func flash(
        window: CGWindowID,
        frame: CGRect,
        text: String
    ) {
        var pill = pills[window] ?? makePill()
        pill.hideWork?.cancel()
        pill.hideWork = nil

        pill.plate.setText(text)
        let textSize = pill.plate.fittingSize
        let pillWidth = min(
            frame.width - 24,
            max(textSize.width + Self.pillPadding, 120)
        )
        // The hide timer was already cancelled above, so a bare
        // return here would strand a showing pill at alpha 1
        // forever — fade it out instead of leaving it.
        guard pillWidth > 40 else {
            pills[window] = pill
            fadeOut(window)
            return
        }

        let pillRect = CGRect(
            x: frame.midX - pillWidth / 2,
            y: frame.minY + 8,
            width: pillWidth,
            height: Self.pillHeight
        )
        let screenRect = GeometryUtils.flip(
            pillRect,
            primaryHeight: GeometryUtils.primaryHeight
        )

        pill.panel.setFrame(screenRect, display: true)
        pill.panel.order(.above, relativeTo: Int(window))
        pill.panel.alphaValue = 1

        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            popEntrance(pill.plate)
        }

        let work = DispatchWorkItem { [weak self] in
            self?.fadeOut(window)
        }
        pill.hideWork = work
        pills[window] = pill
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.holdDuration,
            execute: work
        )
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
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0.95, 1.03, 1.0]
        pop.keyTimes = [0, 0.5, 1.0]
        pop.duration = 0.14
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn),
        ]
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
        panel.contentView = plate
        return panel
    }
}

/// The pill's visual content: frosted blur plate with symbol and label.
@MainActor
private final class SizeLimitPillPlate: NSVisualEffectView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.masksToBounds = true

        icon.image = NSImage(
            systemSymbolName: "arrow.down.right.and.arrow.up.left",
            accessibilityDescription: nil
        )
        icon.contentTintColor = .secondaryLabelColor
        icon.imageScaling = .scaleProportionallyDown
        addSubview(icon)

        label.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    func setText(_ text: String) {
        label.stringValue = text
    }

    override var fittingSize: NSSize {
        let labelSize = label.intrinsicContentSize
        return NSSize(width: labelSize.width + 36, height: 26)
    }

    override func layout() {
        super.layout()
        icon.frame = NSRect(
            x: 8,
            y: (bounds.height - 12) / 2,
            width: 12,
            height: 12
        )
        label.frame = NSRect(
            x: 24,
            y: (bounds.height - 15) / 2,
            width: bounds.width - 30,
            height: 15
        )
    }
}
