import CoreGraphics
import Foundation

/// Gap and minimum-size setters. Both accept the values the
/// GUI's Layouts & Gaps tab produces (see 05_GUI_Concept §3).
extension KiwiCore {
    func setGaps(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        if command == "set_gap_global" {
            guard let gaps = Self.parseGaps(args.first) else {
                return .fail("expected gap size or table")
            }
            tiler.settings.gapsGlobal = gaps
        } else {
            guard let space = args.first?.stringValue,
                let gaps = Self.parseGaps(
                    args.dropFirst().first
                )
            else {
                return .fail("expected space id and size")
            }
            tiler.settings.gapsOverride[SpaceID(space)] = gaps
        }
        // Forced: an explicit gap command must apply even when
        // the delta is within the retile tolerance (±2 pt).
        retile(force: true)
        return .ok()
    }

    /// A gap argument is either a single number (uniform) or a
    /// table with any of `top`/`bottom`/`left`/`right` (outer)
    /// and `inner_horizontal`/`inner_vertical`. Missing keys
    /// keep the uniform default of 10 pt.
    static func parseGaps(_ value: JSONValue?) -> Gaps? {
        if let size = value?.numberValue {
            return .uniform(CGFloat(size))
        }
        guard case .object(let table)? = value else {
            return nil
        }
        func read(_ key: String, _ fallback: CGFloat) -> CGFloat {
            guard let number = table[key]?.numberValue else {
                return fallback
            }
            return CGFloat(number)
        }
        return Gaps(
            outer: Gaps.Outer(
                top: read("top", 10),
                bottom: read("bottom", 10),
                left: read("left", 10),
                right: read("right", 10)
            ),
            inner: Gaps.Inner(
                horizontal: read("inner_horizontal", 10),
                vertical: read("inner_vertical", 10)
            )
        )
    }

    func setMinWindowSize(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let size = args.first?.numberValue else {
            return .fail("expected size")
        }
        tiler.settings.minWindowSize = CGFloat(size)
        retile(force: true)
        return .ok()
    }

    func setSwapSkipsCascade(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected boolean")
        }
        tiler.settings.swapSkipsCascade = on
        // No retile: this only steers which window a directional
        // swap trades with, never any window's frame (#172).
        return .ok()
    }

    func setResizeStep(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.numberValue, raw.isFinite
        else {
            return .fail("expected step")
        }
        // Whole points in a sane range: the catalog funnels this
        // through `Int(...)` when it authors the Lua literal, so
        // an unbounded or non-finite arg must never reach it
        // (`Int(1e300)` / `Int(.nan)` trap); a fractional or
        // non-positive step would author a no-op/inverted resize
        // (#58 review).
        let step = min(max(raw.rounded(), 1), 10_000)
        tiler.settings.resizeStep = CGFloat(step)
        // No retile (unlike set_min_window_size): the step is
        // only consulted when the catalog authors a Grow/Shrink
        // binding and on import read-back — never by layout
        // math — so it can't move a window (#58).
        return .ok()
    }
}
