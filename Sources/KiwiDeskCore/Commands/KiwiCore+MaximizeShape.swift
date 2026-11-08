import Foundation

/// A refused `toggle_maximized` argument (#3062).
struct MaximizeArgRefusal: Error {
    let message: String
    var response: CommandResponse { .fail(message) }
}

/// The directional Maximize's arguments and its `maximize.*`
/// setters (#3062). A press's own share and anchor win over the
/// stored ones; a full Maximize takes neither.
extension KiwiCore {
    /// The shape `args` ask for: none is the whole screen; an axis
    /// takes the stored share and anchor unless the press names
    /// its own.
    func maximizeShape(
        from args: [JSONValue]
    ) -> Result<MaximizeShape, MaximizeArgRefusal> {
        guard let first = args.first else { return .success(.full) }
        guard let raw = first.stringValue,
            let axis = MaximizeAxis(rawValue: raw)
        else {
            return .failure(
                MaximizeArgRefusal(
                    message: "expected \(MaximizeAxis.expectedList)"
                )
            )
        }
        let settings = tiler.settings.maximize
        var share = settings.share(for: axis)
        if args.count > 1 {
            guard let read = args[1].numberValue,
                MaximizeShape.shareRange.contains(read)
            else { return .failure(Self.shareRefusal) }
            share = read
        }
        var anchor = settings.anchor
        if args.count > 2 {
            guard let raw = args[2].stringValue,
                let read = MaximizeAnchor(rawValue: raw)
            else {
                return .failure(
                    MaximizeArgRefusal(
                        message: "expected \(MaximizeAnchor.expectedList)"
                    )
                )
            }
            anchor = read
        }
        return .success(
            MaximizeShape(axis: axis, share: share, anchor: anchor)
        )
    }

    private static let shareRefusal = MaximizeArgRefusal(
        message: "expected a share from "
            + "\(MaximizeShape.shareRange.lowerBound) to "
            + "\(MaximizeShape.shareRange.upperBound)"
    )

    /// `maximize.set_share(axis, share)` and
    /// `maximize.set_anchor(anchor)`: a window already maximized
    /// keeps the shape it was pressed with.
    func maximizeSettingsCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "maximize.set_share":
            guard let raw = args.first?.stringValue,
                let axis = MaximizeAxis(rawValue: raw)
            else { return .expected(MaximizeAxis.self) }
            guard args.count > 1, let share = args[1].numberValue,
                MaximizeShape.shareRange.contains(share)
            else { return Self.shareRefusal.response }
            tiler.settings.maximize.setShare(share, for: axis)
            return .ok()
        case "maximize.set_anchor":
            guard let raw = args.first?.stringValue,
                let anchor = MaximizeAnchor(rawValue: raw)
            else { return .expected(MaximizeAnchor.self) }
            tiler.settings.maximize.anchor = anchor
            return .ok()
        default:
            return .fail("unknown command: \(command)")
        }
    }
}
