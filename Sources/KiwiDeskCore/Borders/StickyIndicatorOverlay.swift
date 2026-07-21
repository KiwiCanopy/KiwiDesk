import AppKit

/// The on-window sticky mark (#414): a small chip wearing the
/// sticky symbol, hugging its window's top-RIGHT corner
/// (top-left belongs to the traffic lights). A border sibling,
/// deliberately independent of `border.enabled` — borders are
/// optional and often off, but a sticky window's state is
/// otherwise invisible.
///
/// AppKit only: a passive marker needs none of the border's
/// SkyLight fast path. The panel stacks directly above its
/// target window, so unrelated windows layered over the target
/// still cover the mark (same band trick as the border's
/// below-order, inverted).
@MainActor
final class StickyIndicatorOverlay {
    /// Chip square and its inset from the window corner.
    /// Final size picked by eye (#414).
    static let size: CGFloat = 20
    static let inset: CGFloat = 6

    private var panel: NSPanel?
    private let target: CGWindowID
    /// The last window frame this chip positioned against (AX
    /// coords) — the observable seam that lets the manager's
    /// WS-tracking guard be tested (a suppressed `follow` leaves
    /// this unchanged; `reposition` advances it).
    private(set) var lastFrame: CGRect?

    init(window: CGWindowID) {
        target = window
    }

    /// Places the chip at `frame`'s top-right (AX coords).
    /// Position only — stacking is `order()`'s job, asserted on
    /// sync, never per tick: a WindowServer reorder per move
    /// event made the chip visibly lag behind its window (the
    /// borders' one-order-per-sync rule, owner QA 2026-07-21).
    func update(frame: CGRect) {
        lastFrame = frame
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let chip = CGRect(
            x: frame.maxX - Self.size - Self.inset,
            y: frame.minY + Self.inset,
            width: Self.size,
            height: Self.size
        )
        panel.setFrame(
            GeometryUtils.flip(
                chip,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: false
        )
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /// Stacks the chip directly above its target window. Called
    /// on sync (steady state), not per follow tick.
    func order() {
        panel?.order(.above, relativeTo: Int(target))
    }

    func hide() {
        panel?.orderOut(nil)
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
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // Normal level + relative order: the chip shares its
        // target's band so windows above the target also cover
        // the chip (the border panel's stacking, inverted).
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        let view = NSVisualEffectView()
        view.wantsLayer = true
        view.material = .hudWindow
        view.state = .active
        view.layer?.cornerRadius = Self.size / 4
        view.layer?.masksToBounds = true
        let symbol = NSImageView()
        symbol.image = NSImage(
            systemSymbolName: StickyStyle.symbolName,
            accessibilityDescription: L(
                "sticky.indicator.ax",
                "Sticky window"
            )
        )
        symbol.symbolConfiguration =
            NSImage.SymbolConfiguration(
                pointSize: Self.size * 0.55,
                weight: .semibold
            )
        symbol.contentTintColor = .labelColor
        symbol.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(symbol)
        NSLayoutConstraint.activate([
            symbol.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            symbol.centerYAnchor.constraint(
                equalTo: view.centerYAnchor
            ),
        ])
        panel.contentView = view
        return panel
    }
}
