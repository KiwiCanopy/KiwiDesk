import AppKit
import CoreGraphics

/// The menu bars the WindowServer DRAWS, as each screen's bar
/// bottom edge in Cocoa y (#1386). `NSScreen.visibleFrame` is
/// AppKit's cache, refreshed only alongside
/// `didChangeScreenParameters` — which macOS skips on some
/// auto-hide toggles, leaving the hidden bar's top for good.
/// `GeometryUtils.axVisibleFrame` clears the band this records;
/// empty means "no correction", the state before the first
/// `EventLoop.publishDisplays` and in every test.
@MainActor
public enum DrawnMenuBars {
    /// Bar bottom edges keyed by screen number.
    static var bottoms: [CGDirectDisplayID: CGFloat] = [:]

    /// The bottom edge of the bar drawn on `screen`, if any.
    static func bottom(of screen: NSScreen) -> CGFloat? {
        guard let number = screen.screenNumber else { return nil }
        return bottoms[number]
    }

    /// Every menu-bar-level window the WindowServer itself lists
    /// on screen, in CG coordinates (origin top-left of the
    /// primary). Matched by owner and level, never by window
    /// name, which reads nil without Screen Recording.
    static func liveBars() -> [CGRect] {
        let level = Int(CGWindowLevelForKey(.mainMenuWindow))
        let list =
            CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly],
                kCGNullWindowID
            ) as? [[String: Any]] ?? []
        return list.compactMap { info in
            guard
                info[kCGWindowOwnerName as String] as? String
                    == "Window Server",
                info[kCGWindowLayer as String] as? Int == level,
                let bounds =
                    info[kCGWindowBounds as String] as? NSDictionary,
                let rect = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return rect
        }
    }

    /// Files `bars` (CG coordinates) under the screen each one
    /// mostly covers. Pure over its inputs.
    static func bottoms(
        of bars: [CGRect],
        screens: [(id: CGDirectDisplayID, frame: CGRect)],
        primaryHeight: CGFloat
    ) -> [CGDirectDisplayID: CGFloat] {
        var result: [CGDirectDisplayID: CGFloat] = [:]
        for bar in bars {
            let cocoa = GeometryUtils.flip(
                bar,
                primaryHeight: primaryHeight
            )
            guard
                let frame = GeometryUtils.rect(
                    mostlyContaining: cocoa,
                    among: screens.map(\.frame)
                ),
                let screen = screens.first(where: {
                    $0.frame == frame
                })
            else { continue }
            result[screen.id] = cocoa.minY
        }
        return result
    }

    /// Re-reads the drawn bars against the live screens.
    static func refresh(bars: [CGRect]) {
        bottoms = bottoms(
            of: bars,
            screens: NSScreen.screens.compactMap { screen in
                screen.screenNumber.map { ($0, screen.frame) }
            },
            primaryHeight: GeometryUtils.primaryHeight
        )
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
