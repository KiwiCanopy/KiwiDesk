import AppKit
import Foundation

/// `track.*` layout sub-API (#128), split out of
/// `KiwiCore+LayoutCommands` for file size.
extension KiwiCore {
    func trackCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "track.set_axis":
            guard
                let axis = Self.parseTrackAxis(
                    args.first?.stringValue
                )
            else { return Self.trackAxisError }
            tiler.settings.track.axis = axis
        case "track.set_limit":
            guard let limit = args.first?.intValue,
                limit >= 0
            else {
                return .fail(
                    "expected a track limit (0 = automatic)"
                )
            }
            // 0 keeps the Lua "0 = automatic" idiom; a positive
            // limit pins the cap and turns automatic off, so
            // `track.set_limit(3)` takes effect without a second
            // call. The remembered magnitude is left untouched by
            // the 0 case (#178). 0 is never STORED — the GUI
            // steppers start at 1 so the field has one meaning.
            if limit == 0 {
                tiler.settings.track.autoTracks = true
            } else {
                tiler.settings.track.limit = limit
                tiler.settings.track.autoTracks = false
            }
        case "track.set_auto_tracks":
            guard let on = args.first?.boolValue else {
                return .fail("expected a boolean")
            }
            tiler.settings.track.autoTracks = on
        case "track.set_new_window":
            guard let raw = args.first?.stringValue,
                let rule = TrackParams.NewWindowTrack(
                    rawValue: raw
                )
            else {
                return .expected(TrackParams.NewWindowTrack.self)
            }
            tiler.settings.track.newWindow = rule
        case "track.set_new_window_position":
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.track.newWindowPosition = placement
        case "track.set_overflow_style":
            guard
                let style = Self.parseTrackOverflowStyle(
                    args.first?.stringValue
                )
            else { return Self.trackOverflowError }
            tiler.settings.track.overflowStyle = style
        case "track.set_wrap_focus":
            guard let on = args.first?.boolValue else {
                return .fail("expected a boolean")
            }
            tiler.settings.track.wrapFocus = on
        default:
            return trackOverrideFallback(command, args)
        }
        return .ok()
    }

    /// `track.set_<field>_override(space, value)` — the
    /// per-space sibling of the global track setters (#17
    /// pattern). Parses the same value via the shared parsers,
    /// writes it into that space's override, and clears the
    /// entry when it becomes empty.
    private func trackOverrideFallback(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command.hasPrefix("track.set_"),
            command.hasSuffix("_override")
        else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("track.set_".count)
                .dropLast("_override".count)
        )
        guard let space = args.first?.stringValue,
            !space.isEmpty
        else { return .fail("expected space id and value") }
        let rest = Array(args.dropFirst())
        var over =
            tiler.settings.track.override[SpaceID(space)]
            ?? TrackOverride()
        switch field {
        case "axis":
            guard
                let axis = Self.parseTrackAxis(
                    rest.first?.stringValue
                )
            else { return Self.trackAxisError }
            over.axis = axis
        case "limit":
            guard let limit = rest.first?.intValue,
                limit >= 0
            else {
                return .fail(
                    "expected a track limit (0 = automatic)"
                )
            }
            // Same coupling as the global setter (#178).
            if limit == 0 {
                over.autoTracks = true
            } else {
                over.limit = limit
                over.autoTracks = false
            }
        case "auto_tracks":
            guard let on = rest.first?.boolValue else {
                return .fail("expected a boolean")
            }
            over.autoTracks = on
        case "overflow_style":
            guard
                let style = Self.parseTrackOverflowStyle(
                    rest.first?.stringValue
                )
            else { return Self.trackOverflowError }
            over.overflowStyle = style
        default:
            return .fail(
                "unknown command: track.set_\(field)_override"
            )
        }
        tiler.settings.track.override[SpaceID(space)] =
            over.isEmpty ? nil : over
        return .ok()
    }

    static func parseTrackAxis(
        _ raw: String?
    ) -> TrackParams.Axis? {
        raw.flatMap(TrackParams.Axis.init(rawValue:))
    }

    /// Shared by the global overflow setter and its per-space
    /// override; reuses stack's `cascade_overflow`/`cascade_all`
    /// vocabulary (#188).
    static func parseTrackOverflowStyle(
        _ raw: String?
    ) -> StackParams.OverflowStyle? {
        raw.flatMap(StackParams.OverflowStyle.init(rawValue:))
    }

    private static let trackAxisError = CommandResponse.expected(
        TrackParams.Axis.self
    )

    private static let trackOverflowError = CommandResponse.expected(
        StackParams.OverflowStyle.self
    )
}
