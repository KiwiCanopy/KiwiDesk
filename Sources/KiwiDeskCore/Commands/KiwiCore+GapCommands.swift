import CoreGraphics
import Foundation

/// Gap and minimum-size setters. Both accept the values the
/// GUI's Layouts & Gaps tab produces.
extension KiwiCore {
    func setGaps(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        if command == "set_gap_global" {
            guard let gaps = Gaps.parse(from: args.first) else {
                return .fail("expected gap size or table")
            }
            tiler.settings.gapsGlobal = gaps
        } else {
            guard let space = args.first?.stringValue,
                let gaps = Gaps.parse(
                    from: args.dropFirst().first
                )
            else {
                return .fail("expected space id and size")
            }
            tiler.settings.gapsOverride[SpaceID(space)] = gaps
        }
        // Forced: an explicit gap command must apply even when
        // the delta is within the retile tolerance (±2 pt).
        // Promises (#593): a gap edit is pure geometry — the
        // same windows in the same slots, every one of them
        // spring-sized from one clock — so the shared edges may
        // slide.
        retile(pass: .apply, sizing: .allSpringSized)
        return .ok()
    }

    /// `set_min_window_size(width, height?, layout?)` (#2237): no
    /// layout sets every layout, no height takes the width, and a
    /// layout name in second place stands for both.
    func setMinWindowSize(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let width = args.first?.numberValue else {
            return .fail("expected width")
        }
        var rest = args.dropFirst()
        var height = width
        switch rest.first {
        case .number(let value)?:
            height = value
            rest = rest.dropFirst()
        case .null?:
            rest = rest.dropFirst()
        default:
            break
        }
        var layout: MinWindowSizes.Layout?
        switch rest.first {
        case .string(let name)?:
            guard let named = MinWindowSizes.Layout(rawValue: name)
            else { return .expected(MinWindowSizes.Layout.self) }
            layout = named
        case nil, .null?:
            break
        default:
            return .expected(MinWindowSizes.Layout.self)
        }
        guard rest.count <= 1 else {
            return .fail("expected at most width, height, layout")
        }
        tiler.settings.minWindowSizes.set(
            MinSize(width: CGFloat(width), height: CGFloat(height)),
            for: layout
        )
        // Promises, like the gap edit above (#593): the floor
        // only re-divides room among the windows already placed.
        // It can flip a track into an overflow cascade, where
        // windows overlap by design — but that pile is
        // spring-sized like everything else in the pass, so no
        // #45 instant sizing enters it.
        retile(pass: .apply, sizing: .allSpringSized)
        return .ok()
    }

    /// `set_min_window_size_override(space, width, height?)`
    /// (#2422): one Space's own floor, outranking its layout's; no
    /// height takes the width.
    func setMinWindowSizeOverride(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let space = args.first?.stringValue,
            let width = args.dropFirst().first?.numberValue
        else {
            return .fail("expected space id and width")
        }
        var height = width
        switch args.dropFirst(2).first {
        case .number(let value)?:
            height = value
        case nil, .null?:
            break
        default:
            return .fail("expected height")
        }
        guard args.count <= 3 else {
            return .fail("expected at most space, width, height")
        }
        tiler.settings.minWindowSizeOverride[SpaceID(space)] =
            MinSize(width: CGFloat(width), height: CGFloat(height))
        // Promises as `set_min_window_size` above (#593).
        retile(pass: .apply, sizing: .allSpringSized)
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

    func setFloatPlacement(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let placement = FloatPlacement(rawValue: raw)
        else {
            return .expected(FloatPlacement.self)
        }
        tiler.settings.floatPlacement = placement
        // No retile: read only when a float verb fires, never by
        // layout math, so setting it moves no window here.
        return .ok()
    }

    func setFloatScaleOnDisplayChange(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected boolean")
        }
        tiler.settings.floatScaleOnDisplayChange = on
        // No retile (like `set_float_placement`): the flag is read
        // only by `FloatReanchor.target` at a display-crossing
        // re-anchor, never by layout math, so flipping it moves
        // nothing here.
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
