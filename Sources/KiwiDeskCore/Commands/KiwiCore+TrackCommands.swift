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
        case "track.set_count":
            guard let count = args.first?.intValue,
                count >= 0
            else {
                return .fail(
                    "expected a track limit (0 = automatic)"
                )
            }
            // 0 keeps the Lua "0 = automatic" idiom; a positive
            // count pins the cap and turns automatic off, so
            // `track.set_count(3)` takes effect without a second
            // call. The remembered magnitude is left untouched by
            // the 0 case (#178).
            if count == 0 {
                tiler.settings.track.autoTracks = true
            } else {
                tiler.settings.track.count = count
                tiler.settings.track.autoTracks = false
            }
        case "track.set_auto_tracks":
            guard let on = args.first?.boolValue else {
                return .fail("expected a boolean")
            }
            tiler.settings.track.autoTracks = on
        case "track.set_overflow_style":
            guard
                let style = Self.parseOverflowStyle(
                    args.first?.stringValue
                )
            else { return Self.overflowStyleError }
            tiler.settings.track.overflowStyle = style
        case "track.set_new_window":
            guard let raw = args.first?.stringValue,
                let rule = TrackParams.NewWindowTrack(
                    rawValue: raw
                )
            else {
                return .fail(
                    "expected own_track | focused_track"
                )
            }
            tiler.settings.track.newWindow = rule
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
        case "count":
            guard let count = rest.first?.intValue,
                count >= 0
            else {
                return .fail(
                    "expected a track limit (0 = automatic)"
                )
            }
            // Same coupling as the global setter (#178).
            if count == 0 {
                over.autoTracks = true
            } else {
                over.count = count
                over.autoTracks = false
            }
        case "auto_tracks":
            guard let on = rest.first?.boolValue else {
                return .fail("expected a boolean")
            }
            over.autoTracks = on
        case "overflow_style":
            guard
                let style = Self.parseOverflowStyle(
                    rest.first?.stringValue
                )
            else { return Self.overflowStyleError }
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

    private static let trackAxisError = CommandResponse.fail(
        "expected vertical|horizontal"
    )
}
