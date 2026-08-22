import AppKit
import CoreGraphics

/// Visual plate and panel for the minimum-size refusal pill (#933).
///
/// Flashed at the top-center of a window when a keyboard resize
/// attempts to shrink past the window's effective minimum size
/// (`min_window_size` or app-enforced `EffectiveSizeBound`).
@MainActor
final class SizeLimitOverlay {
    private var panel: NSPanel?
    private let plate = SizeLimitPillPlate()
    private var hideWork: DispatchWorkItem?

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
        let panel = self.panel ?? makePanel()
        self.panel = panel

        hideWork?.cancel()
        hideWork = nil

        plate.setText(text)
        let textSize = plate.fittingSize
        let pillWidth = min(
            frame.width - 24,
            max(textSize.width + Self.pillPadding, 120)
        )
        // `hideWork` was already cancelled above, so a bare
        // return here would strand a previous pill at alpha 1
        // forever — fade it out instead of leaving it.
        guard pillWidth > 40 else {
            fadeOut()
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

        panel.setFrame(screenRect, display: true)
        panel.order(.above, relativeTo: Int(window))
        panel.alphaValue = 1

        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            popEntrance()
        }

        let work = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.holdDuration,
            execute: work
        )
    }

    private func fadeOut() {
        guard let panel, panel.isVisible else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // AppKit calls the completion on the main thread;
            // the closure is typed `@Sendable`, so hop back
            // into the actor explicitly.
            MainActor.assumeIsolated {
                self?.panel?.orderOut(nil)
            }
        }
    }

    private func popEntrance() {
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

    private func makePanel() -> NSPanel {
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
