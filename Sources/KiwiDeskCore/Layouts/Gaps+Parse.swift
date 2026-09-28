import CoreGraphics
import Foundation

extension Gaps {
    /// A gap argument as `set_gap_global` / `set_gap_override` take
    /// it: one number (uniform), or a table with any of
    /// `top`/`bottom`/`left`/`right` (outer) and
    /// `inner_horizontal`/`inner_vertical`. Missing keys keep the
    /// uniform default of 10 pt; nil for a wrong type.
    public static func parse(from value: JSONValue?) -> Gaps? {
        if let size = value?.numberValue {
            return .uniform(CGFloat(size))
        }
        guard case .object(let table)? = value else { return nil }
        func read(_ key: String) -> CGFloat {
            CGFloat(table[key]?.numberValue ?? 10)
        }
        return Gaps(
            outer: Outer(
                top: read("top"),
                bottom: read("bottom"),
                left: read("left"),
                right: read("right")
            ),
            inner: Inner(
                horizontal: read("inner_horizontal"),
                vertical: read("inner_vertical")
            )
        )
    }

    /// A look's stored `gap.global` (#1739), read by the config's
    /// own decoder — the wire shape it was extracted in. The gap
    /// commands neither clamp nor refuse a number, so this sets
    /// nothing they could not; nil for any other shape.
    static func stored(_ value: JSONValue) -> Gaps? {
        guard let data = try? JSONEncoder().encode(value) else {
            return nil
        }
        return try? JSONDecoder().decode(Gaps.self, from: data)
    }
}
