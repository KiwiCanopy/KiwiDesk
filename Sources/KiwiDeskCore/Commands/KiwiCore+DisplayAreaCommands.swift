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

    /// `set_display_areas`' write, without the retile: a screen
    /// named by number or name while none is known waits for the
    /// first report, whose drain replays this body (#3640).
    func storeDisplayAreas(_ args: [JSONValue]) -> CommandResponse {
        if holdsScreenArg(args.first) {
            holdSettingsCall(split: true) { self.storeDisplayAreas(args) }
            return .ok()
        }
        guard let screen = splitScreen(args.first) else {
            return .fail("unknown screen: \(args.first?.stringValue ?? "")")
        }
        let rest = Array(args.dropFirst())
        let previous = tiler.settings.displayAreas[screen.fingerprint]
        let split: ScreenSplit
        switch parseAreas(rest, screen: screen, previous: previous) {
        case .refused(let response):
            return response
        case .split(let parsed):
            split = parsed
        }
        if let problem = ScreenArea.problem(
            with: split.areas,
            width: screen.width,
            height: screen.height
        ) {
            return .fail(Self.message(for: problem))
        }
        storeSplit(split, on: screen.fingerprint)
        luaAreaSplits.note(
            screen.fingerprint,
            tiler.settings.displayAreas[screen.fingerprint]
        )
        return .ok()
    }

    /// `set_display_area_name(area, name)` names the area its key
    /// names (as `list_monitors` prints it); an empty name clears
    /// it back to the positional default.
    func setDisplayAreaName(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let name = args.dropFirst().first?.stringValue
        else { return .fail("expected an area and a name") }
        let key = ScreenAreaKey(parsing: raw)
        guard var split = tiler.settings.displayAreas[key.fingerprint],
            let at = split.areas.firstIndex(where: {
                $0.id == key.areaID
            })
        else { return .fail("unknown area: \(raw)") }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch ScreenArea.nameProblem(
            trimmed,
            for: key,
            splits: tiler.settings.displayAreas,
            screenNames: state.workspaces.allDisplays.map(\.name)
        ) {
        case .number?:
            return .fail("an area name cannot be a number")
        case .taken?:
            return .fail("another area or screen is already named \(trimmed)")
        case nil:
            break
        }
        let old = split
        split.areas[at].name = trimmed.isEmpty ? nil : trimmed
        tiler.settings.displayAreas[key.fingerprint] = split
        luaAreaSplits.rename(key.fingerprint, from: old, to: split)
        return .ok()
    }

    private func parseAreas(
        _ args: [JSONValue],
        screen: (fingerprint: String, width: Int, height: Int),
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
    func areasJSON(of display: Display) -> JSONValue {
        let areas = state.workspaces.placements(of: display.id)
        guard areas.count > 1 else { return .array([]) }
        return .array(
            areas.map { placement in
                let area = placement.area
                return .object([
                    "key": .string(placement.key.description),
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
