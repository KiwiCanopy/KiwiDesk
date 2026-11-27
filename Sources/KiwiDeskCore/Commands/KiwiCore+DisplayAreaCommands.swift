import CoreGraphics
import Foundation

/// Splitting a screen into areas from Lua and the CLI (#3517):
/// `set_display_areas` writes a screen's split, and
/// `set_display_area_name` names one area.
extension KiwiCore {
    /// `set_display_areas(display)` makes the screen whole again;
    /// `set_display_areas(display, direction, size, size, …)`
    /// splits it into areas of those sizes in points along the
    /// direction; from Lua, `set_display_areas(display, {{x=, y=,
    /// w=, h=, id=, name=}, …})` takes the rects whole. The sizes or
    /// rects must tile the screen exactly.
    func setDisplayAreas(_ args: [JSONValue]) -> CommandResponse {
        let response = storeDisplayAreas(args)
        if response.isSuccess { retile() }
        return response
    }

    /// `set_display_areas`' write, without the retile. The split is
    /// stored as the shares of a screen number (#3647 ▸ lane 3): a
    /// connected screen's by its own size, else a number's by the
    /// argument's own extent. A screen named by fingerprint or name
    /// while none is known waits for the first report, whose drain
    /// replays this body (#3640).
    func storeDisplayAreas(_ args: [JSONValue]) -> CommandResponse {
        if holdsNumberedScreenArg(args.first) {
            holdSettingsCall(split: true) { [unowned self] in
                self.storeDisplayAreas(args)
            }
            return .ok()
        }
        let rest = Array(args.dropFirst())
        guard let target = splitTarget(args.first, rest) else {
            return .fail("unknown screen: \(args.first?.stringValue ?? "")")
        }
        guard let number = target.number else {
            return .fail("a screen with no number holds no split")
        }
        let previous = tiler.settings.displayAreas[number: number]
        let split: ScreenSplit
        switch parseAreas(
            rest,
            screen: target.size,
            previous: previous?.resolved(
                width: target.size.width,
                height: target.size.height
            )
        ) {
        case .refused(let response):
            return response
        case .split(let parsed):
            split = parsed
        }
        if let problem = ScreenArea.problem(
            with: split.areas,
            width: target.size.width,
            height: target.size.height
        ) {
            return .fail(Self.message(for: problem))
        }
        // A connected screen draws a split under the floor whole, so
        // the write that would make one is refused (#3647 ▸ lane 3).
        if target.connected,
            case .tooSmall(let axis) = ScreenSplit.verdict(
                split,
                width: target.size.width,
                height: target.size.height,
                floors: tiler.settings.areaFloors
            )
        {
            return .fail(Self.floorMessage(axis))
        }
        storeShares(
            ScreenShares(
                split,
                width: target.size.width,
                height: target.size.height,
                keeping: previous
            ),
            number: number
        )
        luaAreaSplits.note(
            String(number),
            tiler.settings.displayAreas[number: number]
        )
        return .ok()
    }

    /// The number a split names and the extent its sizes are read
    /// against: a connected screen's own, else for a bare number the
    /// extent the sizes or rects span. Nil for an unknown screen; a
    /// nil number for a connected screen that holds none.
    private func splitTarget(
        _ arg: JSONValue?,
        _ rest: [JSONValue]
    ) -> (number: Int?, size: (width: Int, height: Int), connected: Bool)? {
        if let screen = splitScreen(arg) {
            return (
                liveScreenOrder.number(of: screen.fingerprint),
                (screen.width, screen.height),
                true
            )
        }
        if let raw = arg?.stringValue, Self.isFingerprint(raw),
            let size = ScreenShares.size(of: raw)
        {
            // A screen not connected: the number the live profile's
            // first setup holding it gives it.
            let set = profiles.active?.monitorSets.first {
                $0.monitors.contains(raw)
            }
            return (set?.order.number(of: raw), size, false)
        }
        guard let number = arg?.intValue, number >= 1 else { return nil }
        return (number, Self.extent(of: rest), false)
    }

    /// The extent `args` span when no screen gives one: the sizes'
    /// sum along their direction, the rects' far edges, a share's
    /// whole on any side they leave open.
    private static func extent(
        of args: [JSONValue]
    ) -> (width: Int, height: Int) {
        let whole = ScreenShares.whole
        if case .array(let list)? = args.first, args.count == 1 {
            var width = 0
            var height = 0
            for case .object(let fields) in list {
                width = max(
                    width,
                    (fields["x"]?.intValue ?? 0) + (fields["w"]?.intValue ?? 0)
                )
                height = max(
                    height,
                    (fields["y"]?.intValue ?? 0) + (fields["h"]?.intValue ?? 0)
                )
            }
            return (max(width, 1), max(height, 1))
        }
        let along = max(
            args.dropFirst().compactMap(\.intValue).reduce(0, +),
            1
        )
        switch args.first?.stringValue.flatMap(ScreenAreaCut.Axis.init) {
        case .sideBySide?: return (along, whole)
        case .stacked?: return (whole, along)
        case nil: return (whole, whole)
        }
    }

    /// `set_display_area_name(area, name)` names the area its key
    /// names (as `list_monitors` prints it, or `N#id`); an empty name
    /// clears it back to the positional default. Behind a split a
    /// load holds for the first screen report, or naming a screen by
    /// fingerprint while none is known, it waits too (#3640).
    func setDisplayAreaName(_ args: [JSONValue]) -> CommandResponse {
        if luaAreaSplits.isRecording,
            heldScreenCalls.contains(where: \.isSplit)
                || holdsNumberedScreenArg(args.first)
        {
            holdSettingsCall(split: false) { [unowned self] in
                self.setDisplayAreaName(args)
            }
            return .ok()
        }
        guard let raw = args.first?.stringValue,
            let name = args.dropFirst().first?.stringValue
        else { return .fail("expected an area and a name") }
        let order = liveScreenOrder
        guard
            let slot = ScreenSlotKey(parsing: raw)
                ?? order.slot(of: ScreenAreaKey(parsing: raw)),
            var shares = tiler.settings.displayAreas[number: slot.number],
            let at = shares.areas.firstIndex(where: {
                $0.id == slot.areaID
            })
        else { return .fail("unknown area: \(raw)") }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        // A number no screen holds has no runtime area to collide
        // with, so only the name's own shape is judged.
        let key = order.runtimeKey(of: slot)
        switch ScreenArea.nameProblem(
            trimmed,
            for: key,
            splits: key == nil
                ? [:]
                : tiler.settings.displayAreas.splits(
                    order: order,
                    floors: .unfloored
                ),
            screenNames: key == nil
                ? [] : state.workspaces.allDisplays.map(\.name)
        ) {
        case .number?:
            return .fail("an area name cannot be a number or N#id")
        case .taken?:
            return .fail("another area or screen is already named \(trimmed)")
        case nil:
            break
        }
        let old = shares
        shares.areas[at].name = trimmed.isEmpty ? nil : trimmed
        tiler.settings.displayAreas[number: slot.number] = shares
        luaAreaSplits.rename(String(slot.number), from: old, to: shares)
        return .ok()
    }

    private func parseAreas(
        _ args: [JSONValue],
        screen: (width: Int, height: Int),
        previous: ScreenSplit?
    ) -> AreaParse {
        let whole = ScreenSplit.whole(
            width: screen.width,
            height: screen.height,
            after: previous
        )
        guard let first = args.first else { return .split(whole) }
        if case .array(let list) = first, args.count == 1 {
            return Self.rectSplit(list, after: previous)
        }
        guard let raw = first.stringValue,
            let axis = ScreenAreaCut.Axis(rawValue: raw)
        else {
            return .refused(.expected(ScreenAreaCut.Axis.self))
        }
        let sizes = args.dropFirst().compactMap(\.intValue)
        guard sizes.count == args.count - 1, !sizes.isEmpty else {
            return .refused(.fail("expected sizes in points"))
        }
        return .split(
            ScreenSplit.laidOut(
                sizes,
                axis: axis,
                width: screen.width,
                height: screen.height,
                after: previous
            )
        )
    }

    private static func rectSplit(
        _ list: [JSONValue],
        after previous: ScreenSplit?
    ) -> AreaParse {
        var entries: [(id: Int?, area: ScreenArea)] = []
        for entry in list {
            guard case .object(let fields) = entry,
                let x = fields["x"]?.intValue,
                let y = fields["y"]?.intValue,
                let w = fields["w"]?.intValue,
                let h = fields["h"]?.intValue
            else {
                return .refused(.fail("expected areas as {x, y, w, h}"))
            }
            let area = ScreenArea(
                id: 0,
                x: x,
                y: y,
                w: w,
                h: h,
                name: fields["name"]?.stringValue
            )
            entries.append((fields["id"]?.intValue, area))
        }
        return .split(ScreenSplit.adopting(entries, after: previous))
    }

    /// The refusal for a split a screen would draw whole.
    static func floorMessage(_ axis: ScreenAreaCut.Axis) -> String {
        let side = axis == .sideBySide ? "narrower" : "shorter"
        return "areas would be \(side) than the minimum window size"
    }

    /// The refusal for a broken split, naming the rule it breaks.
    static func message(for problem: ScreenAreaProblem) -> String {
        switch problem {
        case .empty: "expected at least one area"
        case .duplicateID(let id): "area id \(id) is used twice"
        case .negativeID(let id): "area id \(id) is negative"
        case .tooSmall(let id):
            "area \(id) is smaller than \(ScreenArea.minimumSide) points"
        case .outsideScreen(let id): "area \(id) reaches past the screen"
        case .overlap(let a, let b): "areas \(a) and \(b) overlap"
        case .gap: "the areas must cover the whole screen"
        case .notGuillotine:
            "the areas must be separable by straight lines"
        case .missingLeadArea:
            "the top-left area must keep id 0"
        }
    }
}

/// A parsed split, or the refusal that answers the call.
enum AreaParse {
    case split(ScreenSplit)
    case refused(CommandResponse)
}

extension KiwiCore {
    /// `list_monitors`' areas for `display`: each area's key, its
    /// name if any, and its rect in the screen's own points — read
    /// off the placement list, so it shows the split in effect.
    func areasJSON(of display: Display, screen: Int?) -> JSONValue {
        let areas = state.workspaces.placements(of: display.id)
        guard areas.count > 1 else { return .array([]) }
        return .array(
            areas.map { placement in
                let area = placement.area
                return .object([
                    "key": .string(placement.key.description),
                    // Screen N's area, as a script names it (#3647).
                    "numbered_key": screen.flatMap {
                        ScreenSlotKey(number: $0, areaID: area.id)
                    }.map { .string($0.description) } ?? .null,
                    "name": area.name.map(JSONValue.string) ?? .null,
                    "x": .number(Double(area.x)),
                    "y": .number(Double(area.y)),
                    "w": .number(Double(area.w)),
                    "h": .number(Double(area.h)),
                    // The Space this area shows (#3549, #3517).
                    "space_id": state.workspaces.activeSpace(
                        on: placement.id
                    ).map { .string($0.raw) } ?? .null,
                ])
            }
        )
    }
}
