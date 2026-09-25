import AppKit
import CoreGraphics

/// The menu bars the WindowServer DRAWS, as each screen's bar
/// bottom edge in Cocoa y (#1386) — what `GeometryUtils
/// .visibleFrame(of:)` clears when AppKit's cached frame has not
/// caught up. Empty means no correction.
@MainActor
public enum DrawnMenuBars {
    /// Bar bottom edges keyed by screen number.
    static var bottoms: [CGDirectDisplayID: CGFloat] = [:]

    /// The deepest bar a screen's top may carry; a taller window
    /// at the menu-bar level is not a menu bar.
    static let maxBarHeight: CGFloat = 60

    /// The bottom edge of the bar drawn on `screen`, if any.
    static func bottom(of screen: NSScreen) -> CGFloat? {
        guard let number = screen.screenNumber else { return nil }
        return bottoms[number]
    }

    /// Files `bars` (CG coordinates) under the screen whose TOP
    /// edge each one sits on; the deepest wins where several do.
    /// Pure over its inputs.
    static func bottoms(
        of bars: [CGRect],
        screens: [(id: CGDirectDisplayID, frame: CGRect)],
        primaryHeight: CGFloat
    ) -> [CGDirectDisplayID: CGFloat] {
        var result: [CGDirectDisplayID: CGFloat] = [:]
        for bar in bars where bar.height <= maxBarHeight {
            let cocoa = GeometryUtils.flip(
                bar,
                primaryHeight: primaryHeight
            )
            guard
                let frame = GeometryUtils.rect(
                    mostlyContaining: cocoa,
                    among: screens.map(\.frame)
                ),
                abs(cocoa.maxY - frame.maxY) <= 1,
                let screen = screens.first(where: {
                    $0.frame == frame
                })
            else { continue }
            result[screen.id] = min(
                result[screen.id] ?? cocoa.minY,
                cocoa.minY
            )
        }
        return result
    }

    /// Re-reads the drawn bars against the live screens; returns
    /// whether the answer changed.
    @discardableResult
    static func refresh(bars: [CGRect]) -> Bool {
        let fresh = bottoms(
            of: bars,
            screens: NSScreen.screens.compactMap { screen in
                screen.screenNumber.map { ($0, screen.frame) }
            },
            primaryHeight: GeometryUtils.primaryHeight
        )
        defer { bottoms = fresh }
        return fresh != bottoms
    }
}

extension NSScreen {
    /// The CoreGraphics display number AppKit files this screen
    /// under.
    var screenNumber: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value
    }
}
