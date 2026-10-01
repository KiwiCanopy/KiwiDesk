import AppKit
import CoreGraphics

/// Coordinate conversion helpers between Cocoa bottom-left and AX top-left
/// origins.
public enum GeometryUtils {
    /// The rect in `rects` that `frame` overlaps most, nil when it
    /// overlaps none — the one copy of the rule
    /// `TilingEngine.screen(containing:)` and the traveler
    /// re-home (#1217) share.
    public static func rect(
        mostlyContaining frame: CGRect,
        among rects: [CGRect]
    ) -> CGRect? {
        func overlap(_ rect: CGRect) -> CGFloat {
            let shared = rect.intersection(frame)
            return shared.isNull ? 0 : shared.width * shared.height
        }
        return
            rects
            .filter { overlap($0) > 0 }
            .max { overlap($0) < overlap($1) }
    }

    /// macOS window corner radius constant (`BorderGeometry`,
    /// `TilingSettings.windowStroke`).
    public static let systemWindowCornerRadius: CGFloat = 16

    /// Flips a rect between Cocoa and AX coordinate systems.
    public static func flip(
        _ rect: CGRect,
        primaryHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Height of the primary display (Cocoa origin screen).
    @MainActor
    public static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Flips a screen point between Cocoa and AX coordinates.
    @MainActor
    public static func axPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// A screen's usable area in AX coordinates — `visibleFrame(of:)`
    /// flipped.
    @MainActor
    public static func axVisibleFrame(
        of screen: NSScreen
    ) -> CGRect {
        flip(visibleFrame(of: screen), primaryHeight: primaryHeight)
    }

    /// A screen's usable area in Cocoa coordinates: reclaims an
    /// auto-hidden menu bar and clears a drawn one AppKit's cached
    /// `visibleFrame` has not caught up with (#1386). Core reads
    /// a screen's usable area through here;
    /// `VisibleFrameReadCensusTests` holds the exceptions.
    @MainActor
    static func visibleFrame(of screen: NSScreen) -> CGRect {
        let visible = appKitVisibleFrame(of: screen)
        if menuBarAutoHides {
            return reclaimingMenuBar(
                visible,
                screen: screen.frame,
                safeTop: screen.safeAreaInsets.top
            )
        }
        return clearingMenuBar(
            visible,
            barBottom: DrawnMenuBars.bottom(of: screen)
        )
    }

    /// AppKit's own usable area — the WindowServer round trip
    /// under `visibleFrame(of:)`, before the #1386 correction.
    @MainActor
    static func appKitVisibleFrame(of screen: NSScreen) -> CGRect {
        #if DEBUG
            if let appKitVisibleFrameOverride {
                return appKitVisibleFrameOverride(screen)
            }
        #endif
        return liveAppKitVisibleFrame(of: screen)
    }

    /// The machine read behind `appKitVisibleFrame(of:)`.
    @MainActor
    static func liveAppKitVisibleFrame(of screen: NSScreen) -> CGRect {
        screen.visibleFrame
    }

    #if DEBUG
        /// Test seam over `appKitVisibleFrame(of:)`; nil reads the
        /// machine. A test core memoizes it, the correction above
        /// still running live (#1868).
        @MainActor
        static var appKitVisibleFrameOverride: ((NSScreen) -> CGRect)?
    #endif

    /// Lowers `visible`'s top edge to a drawn bar's bottom edge
    /// when it reaches past it; never raises it (#1386).
    static func clearingMenuBar(
        _ visible: CGRect,
        barBottom: CGFloat?
    ) -> CGRect {
        guard let barBottom, visible.maxY > barBottom else {
            return visible
        }
        var result = visible
        result.size.height -= visible.maxY - barBottom
        return result
    }

    /// True when the macOS menu bar is configured to auto-hide.
    public static var menuBarAutoHides: Bool {
        let domain = UserDefaults.standard.persistentDomain(
            forName: UserDefaults.globalDomain
        )
        return (domain?["_HIHideMenuBar"] as? NSNumber)?
            .boolValue ?? false
    }

    /// Extends visibleFrame top edge over menu bar while preserving notch
    /// safeTop.
    static func reclaimingMenuBar(
        _ visible: CGRect,
        screen frame: CGRect,
        safeTop: CGFloat
    ) -> CGRect {
        var result = visible
        let top = frame.maxY - safeTop
        if top > result.maxY {
            result.size.height += top - result.maxY
        }
        return result
    }
}

/// Where an auto-hidden menu bar reveals from (#1532): the top
/// band of the screen the pointer is on, as deep as the bar the
/// reveal draws — the notch's safe area where there is one, the
/// menu bar's own height elsewhere. Pure over the frames handed
/// in; `MouseTracker.pointerInMenuBarStrip` is the live reading.
extension GeometryUtils {
    /// One screen's frame and band, Cocoa coordinates (origin
    /// bottom-left, `NSScreen.frame`'s).
    struct MenuBarScreen: Equatable {
        var frame: CGRect
        var band: CGFloat
    }

    /// The deepest of the three readings a screen offers: its
    /// safe area (the notch), the strip it reserves above its
    /// visible frame, and the installed main menu's bar height —
    /// a bare `NSMenu()` answers 0, the installed one the metric.
    static func menuBarBand(
        safeTop: CGFloat,
        reservedTop: CGFloat,
        barHeight: CGFloat
    ) -> CGFloat {
        max(safeTop, reservedTop, barHeight)
    }

    /// `pointer` in Cocoa screen coordinates, its screen picked
    /// by `screenIndex(holding:in:)`.
    static func pointerInMenuBarStrip(
        _ pointer: CGPoint,
        screens: [MenuBarScreen]
    ) -> Bool {
        guard
            let index = screenIndex(
                holding: pointer,
                in: screens.map(\.frame)
            )
        else { return false }
        let screen = screens[index]
        return pointer.y >= screen.frame.maxY - screen.band
    }

    /// Which of `frames` (Cocoa) holds `point`. A point resting
    /// ON a top edge reads `y == frame.maxY`, which
    /// `CGRect.contains` excludes — so the containing frame is
    /// preferred (a point on the seam between stacked screens is
    /// the upper one's bottom row) and the inclusive-top match is
    /// the fallback for the edge itself.
    static func screenIndex(
        holding point: CGPoint,
        in frames: [CGRect]
    ) -> Int? {
        frames.firstIndex(where: { $0.contains(point) })
            ?? frames.firstIndex(where: {
                $0.minX <= point.x && point.x < $0.maxX
                    && $0.minY <= point.y && point.y <= $0.maxY
            })
    }

    /// The display whose whole screen — menu bar and Dock strip
    /// included — holds `point` (AX space); the scroll gestures'
    /// one lookup (#1656, #1519).
    @MainActor
    static func display(at point: CGPoint) -> DisplayID? {
        let screens = NSScreen.screens
        guard
            let index = screenIndex(
                holding: axPoint(point),
                in: screens.map(\.frame)
            )
        else { return nil }
        return screens[index].kiwiDisplayID
    }

    /// Confines the origin so `frame` stays inside `visible`; an
    /// oversized frame pins at the region's leading edges.
    static func confine(
        _ frame: CGRect,
        to visible: CGRect
    ) -> CGRect {
        let maxX = max(visible.minX, visible.maxX - frame.width)
        let maxY = max(visible.minY, visible.maxY - frame.height)
        let x = min(max(frame.minX, visible.minX), maxX)
        let y = min(max(frame.minY, visible.minY), maxY)
        return CGRect(
            x: x,
            y: y,
            width: frame.width,
            height: frame.height
        )
    }
}
