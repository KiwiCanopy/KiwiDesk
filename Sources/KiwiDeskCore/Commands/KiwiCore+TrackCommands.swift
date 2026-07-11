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
                    "expected a track limit (0 = dynamic)"
                )
            }
            tiler.settings.track.count = count
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
                    "expected a track limit (0 = dynamic)"
                )
            }
            over.count = count
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
