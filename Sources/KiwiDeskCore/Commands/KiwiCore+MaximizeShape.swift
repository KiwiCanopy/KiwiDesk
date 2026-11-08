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
    /// takes the share and anchor stored for the shape of the
    /// screen `space` lays out on, unless the press names its own.
    /// The one reader of the table at a press, so a per-Space layer
    /// (#3090) outranks it here.
    func maximizeShape(
        from args: [JSONValue],
        for space: SpaceID?
    ) -> Result<MaximizeShape, MaximizeArgRefusal> {
        guard let first = args.first else { return .success(.full) }
        let shape = maximizeScreenShape(of: space)
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
        var share = settings.share(for: axis, on: shape)
        if args.count > 1 {
            guard let read = args[1].numberValue,
                MaximizeShape.shareRange.contains(read)
            else { return .failure(Self.shareRefusal) }
            share = read
        }
        var anchor = settings.anchor[shape]
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

    /// The shape of the screen `space` lays out on, by the rule
    /// `TilingEngine.screen(for:in:)` fills on: its assigned display,
    /// else the main screen. Read from the tracked `Display` first,
    /// so a fixture's display answers; Widescreen with no screen.
    func maximizeScreenShape(of space: SpaceID?) -> ScreenShape {
        let main = ScreenList.mainOrFirst
        let id =
            space.flatMap { state.workspaces.display(of: $0) }
            ?? main?.kiwiDisplayID
        if let display = id.flatMap({ state.workspaces.displays[$0] }) {
            return ScreenShape.of(display)
        }
        return main.map { ScreenShape(ScreenClass.of($0.frame.size)) }
            ?? .widescreen
    }

    /// `maximize.set_share(axis, share[, shape])` and
    /// `maximize.set_anchor(anchor[, shape])`: no shape writes every
    /// one. A window already maximized keeps the shape it was
    /// pressed with.
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
            let shape: ScreenShape?
            switch Self.screenShapeArgument(args, at: 2) {
            case .success(let read): shape = read
            case .failure(let refusal): return refusal.response
            }
            tiler.settings.maximize.setShare(share, for: axis, on: shape)
            return .ok()
        case "maximize.set_anchor":
            guard let raw = args.first?.stringValue,
                let anchor = MaximizeAnchor(rawValue: raw)
            else { return .expected(MaximizeAnchor.self) }
            let shape: ScreenShape?
            switch Self.screenShapeArgument(args, at: 1) {
            case .success(let read): shape = read
            case .failure(let refusal): return refusal.response
            }
            tiler.settings.maximize.anchor.set(anchor, on: shape)
            return .ok()
        default:
            return .fail("unknown command: \(command)")
        }
    }

    /// The optional shape at `index`: absent is nil, every shape.
    private static func screenShapeArgument(
        _ args: [JSONValue],
        at index: Int
    ) -> Result<ScreenShape?, MaximizeArgRefusal> {
        guard args.count > index else { return .success(nil) }
        guard let raw = args[index].stringValue,
            let shape = ScreenShape(rawValue: raw)
        else {
            return .failure(
                MaximizeArgRefusal(
                    message: "expected \(ScreenShape.expectedList)"
                )
            )
        }
        return .success(shape)
    }
}
