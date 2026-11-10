import Foundation

/// The per-Space Maximize setters (#3090), Space first like every
/// `_override` twin; `nil` clears. A window already maximized keeps
/// the shape it was pressed with, as `maximize.set_share` does.
extension KiwiCore {
    /// `maximize.set_share_override(space, axis, share|nil)`.
    func setMaximizeShareOverride(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let space = args.first?.stringValue else {
            return .fail("expected space id")
        }
        guard let raw = args.dropFirst().first?.stringValue,
            let axis = MaximizeAxis(rawValue: raw)
        else { return .expected(MaximizeAxis.self) }
        let share: Double?
        switch args.dropFirst(2).first {
        case nil, .null?:
            share = nil
        case let value?:
            guard let read = value.numberValue,
                MaximizeShape.shareRange.contains(read)
            else {
                return .fail(
                    "expected a share from "
                        + "\(MaximizeShape.shareRange.lowerBound) to "
                        + "\(MaximizeShape.shareRange.upperBound)"
                )
            }
            share = read
        }
        tiler.settings.maximize.setShareOverride(
            share,
            for: axis,
            in: SpaceID(space)
        )
        return .ok()
    }

    /// `maximize.set_anchor_override(space, anchor|nil)`.
    func setMaximizeAnchorOverride(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let space = args.first?.stringValue else {
            return .fail("expected space id")
        }
        let anchor: MaximizeAnchor?
        switch args.dropFirst().first {
        case nil, .null?:
            anchor = nil
        case let value?:
            guard let raw = value.stringValue,
                let read = MaximizeAnchor(rawValue: raw)
            else { return .expected(MaximizeAnchor.self) }
            anchor = read
        }
        tiler.settings.maximize.anchorOverride[SpaceID(space)] = anchor
        return .ok()
    }
}
