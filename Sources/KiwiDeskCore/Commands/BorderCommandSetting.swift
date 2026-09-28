import CoreGraphics
import Foundation

/// A parsed `border.set_*` setting (#278): the one parse the
/// command and a look (#1739) share, so a look can never set a
/// value the command could not. The two colours stay the
/// command's own — a look's colours are its palette's.
enum BorderCommandSetting: Equatable {
    case enabled(Bool)
    case unfocusedEnabled(Bool)
    case width(CGFloat)
    case glow(Bool)
    case glowSize(CGFloat)
    case sheen(CGFloat)
    case cornerStyle(BorderStyle.CornerStyle)
    case drawOrder(BorderStyle.DrawOrder)

    /// Parses a setter's field (the verb minus `set_`) and args;
    /// nil for a field this type does not parse. Out-of-range
    /// magnitudes clamp; a wrong type, an unknown choice or a
    /// negative glow size fails.
    static func parse(
        field: String,
        args: [JSONValue]
    ) -> Result<Self, BorderSettingError>? {
        let first = args.first
        switch field {
        case "enabled":
            return flag(first).map(Self.enabled)
        case "unfocused_enabled":
            return flag(first).map(Self.unfocusedEnabled)
        case "glow":
            return flag(first).map(Self.glow)
        case "width":
            guard let width = first?.numberValue else {
                return .failure(.init(.fail("expected width (pt)")))
            }
            return .success(
                .width(
                    min(
                        BorderStyle.maxWidth,
                        max(BorderStyle.minWidth, width)
                    )
                )
            )
        case "glow_size":
            return glowSize(first)
        case "sheen":
            guard let sheen = BorderStyle.sheen(from: first) else {
                let range = BorderStyle.sheenRange
                return .failure(
                    .init(
                        .fail(
                            "expected a sheen from "
                                + "\(range.lowerBound.formatted()) "
                                + "to \(range.upperBound.formatted())"
                        )
                    )
                )
            }
            return .success(.sheen(sheen))
        case "corner_style":
            return choice(first, BorderStyle.CornerStyle.self)
                .map(Self.cornerStyle)
        case "draw_order":
            return choice(first, BorderStyle.DrawOrder.self)
                .map(Self.drawOrder)
        default:
            return nil
        }
    }

    /// Writes the parsed value into `style`.
    func apply(to style: inout BorderStyle) {
        switch self {
        case .enabled(let on): style.enabled = on
        case .unfocusedEnabled(let on): style.unfocusedEnabled = on
        case .width(let width): style.width = width
        case .glow(let on): style.glow = on
        case .glowSize(let size): style.glowSize = size
        case .sheen(let sheen): style.sheen = sheen
        case .cornerStyle(let corner): style.cornerStyle = corner
        case .drawOrder(let order): style.drawOrder = order
        }
    }

    private static func flag(
        _ value: JSONValue?
    ) -> Result<Bool, BorderSettingError> {
        guard let flag = value?.boolValue else {
            return .failure(.init(.fail("expected boolean")))
        }
        return .success(flag)
    }

    /// 0 = automatic (#551); an explicit size clamps only at the
    /// renderable ceiling. Negative REJECTS rather than clamping:
    /// clamping to 0 would flip into the automatic regime, which
    /// can make the glow bigger.
    private static func glowSize(
        _ value: JSONValue?
    ) -> Result<Self, BorderSettingError> {
        guard let size = value?.numberValue, size.isFinite, size >= 0
        else {
            return .failure(
                .init(.fail("expected size (pt) >= 0, 0 = automatic"))
            )
        }
        return .success(.glowSize(min(BorderStyle.maxGlowSize, size)))
    }

    private static func choice<T: APIChoiceType>(
        _ value: JSONValue?,
        _ type: T.Type
    ) -> Result<T, BorderSettingError> {
        guard let raw = value?.stringValue, let parsed = T(rawValue: raw)
        else { return .failure(.init(.expected(T.self))) }
        return .success(parsed)
    }
}

/// A `border.set_*` refusal, carrying the command's own response.
struct BorderSettingError: Error {
    let response: CommandResponse
    init(_ response: CommandResponse) { self.response = response }
}
