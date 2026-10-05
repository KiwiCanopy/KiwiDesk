import AppKit
import QuartzCore

/// The plate slide's staging (#1956): a play's views, its sticky
/// holes, its pages and its panel per screen.
extension SpaceSlideOverlay {
    /// A fresh play on `press.display`'s panel, ordering the panel
    /// in the first time only.
    func start(_ press: Press) -> Play {
        retireGonePanels()
        let panel = panels[press.display] ?? Self.makePanel()
        panels[press.display] = panel
        if panel.frame != press.screen {
            panel.setFrame(press.screen, display: false)
        }
        let bounds = CGRect(origin: .zero, size: press.screen.size)
        let root = NSView(frame: bounds)
        root.wantsLayer = true
        root.layer?.opacity = 0
        let holeHost = NSView(frame: bounds)
        holeHost.wantsLayer = true
        root.addSubview(holeHost)
        let strip = NSView(frame: bounds)
        strip.wantsLayer = true
        holeHost.addSubview(strip)
        panel.contentView = root
        if !panel.isVisible { present(panel) }
        return Play(
            display: press.display,
            panel: panel,
            screen: press.screen,
            axis: press.axis,
            fader: root.layer ?? CALayer(),
            holeHost: holeHost,
            strip: strip,
            glass: press.glass,
            space: press.space
        )
    }

    /// The sticky windows stay on screen above the plates: a hole
    /// in the strip's host, fixed to the screen while it moves.
    func setHoles(_ holes: [CGRect], in current: Play) {
        guard !holes.isEmpty else {
            current.holeHost.layer?.mask = nil
            return
        }
        let bounds = current.holeHost.bounds
        let path = CGMutablePath()
        path.addRect(bounds)
        for hole in holes { path.addRect(local(hole, in: current)) }
        let mask = CAShapeLayer()
        mask.frame = bounds
        mask.path = path
        mask.fillRule = .evenOdd
        current.holeHost.layer?.mask = mask
    }

    func replacePage(
        at offset: CGFloat,
        with plates: [SpaceSlidePlan.Plate],
        in current: inout Play
    ) {
        current.pages[offset]?.removeFromSuperview()
        let page = pageView(plates, at: offset, in: current)
        current.strip.addSubview(page)
        current.pages[offset] = page
    }

    /// Drops every page farther than one page from the strip's
    /// path, so a long burst keeps a bounded strip.
    func prunePages(_ current: inout Play) {
        let low = min(current.motion.from, current.target)
        let high = max(current.motion.from, current.target)
        let reach = current.pageLength - 1
        for (offset, page) in current.pages
        where offset < low - reach || offset > high + reach {
            page.removeFromSuperview()
            current.pages[offset] = nil
        }
    }

    /// Orders out the panel of a screen no longer connected.
    private func retireGonePanels() {
        let live = Set(NSScreen.screens.compactMap(\.kiwiDisplayID))
        for (display, panel) in panels where !live.contains(display) {
            panel.orderOut(nil)
            panels[display] = nil
        }
    }

    private static func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        panel.level = NSWindow.Level(rawValue: BarPanel.level.rawValue - 1)
        panel.ignoresMouseEvents = true
        // On every Desktop, since it is ordered in once and stays.
        panel.collectionBehavior = [
            .transient, .ignoresCycle, .canJoinAllSpaces, .stationary,
        ]
        return panel
    }
}
