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
        tiler.settings.displayAreas[screen.fingerprint] =
            split.isWhole ? nil : split
        retile()
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
        if !trimmed.isEmpty {
            if trimmed.allSatisfy(\.isNumber) {
                return .fail("an area name cannot be a number")
            }
            if areaNameTaken(trimmed, except: key) {
                return .fail("another area is already named \(trimmed)")
            }
        }
        split.areas[at].name = trimmed.isEmpty ? nil : trimmed
        tiler.settings.displayAreas[key.fingerprint] = split
        return .ok()
    }

    /// The screen a split names: a connected screen by number,
    /// fingerprint or name, else a fingerprint whose size it reads.
    private func splitScreen(
        _ arg: JSONValue?
    ) -> (fingerprint: String, width: Int, height: Int)? {
        if let id = resolveDisplayArg(arg),
            let display = state.workspaces.allDisplays.first(where: {
                $0.id == id
            })
        {
            return (
                display.fingerprint,
                Int(display.frame.width),
                Int(display.frame.height)
            )
        }
        guard let raw = arg?.stringValue,
            ScreenAreaKey.isFingerprint(raw)
        else { return nil }
        let sides = Display.fingerprintParts(raw).size
            .split(separator: "x").compactMap { Int($0) }
        guard sides.count == 2 else { return nil }
        return (raw, sides[0], sides[1])
    }

    private func parseAreas(
        _ args: [JSONValue],
        screen: (fingerprint: String, width: Int, height: Int),
        previous: ScreenSplit?
    ) -> AreaParse {
        let whole = ScreenSplit.whole(
            width: screen.width,
            height: screen.height
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
        let base = ScreenSplit(
            areas: sizes.indices.map {
                ScreenArea(
                    id: $0,
                    x: 0,
                    y: 0,
                    w: screen.width,
                    h: screen.height
                )
            },
            nextID: previous?.nextID
        )
        return .split(base.resized(sizes, axis: axis))
    }

    private static func rectSplit(
        _ list: [JSONValue],
        after previous: ScreenSplit?
    ) -> AreaParse {
        var areas: [ScreenArea] = []
        for (index, entry) in list.enumerated() {
            guard case .object(let fields) = entry,
                let x = fields["x"]?.intValue,
                let y = fields["y"]?.intValue,
                let w = fields["w"]?.intValue,
                let h = fields["h"]?.intValue
            else {
                return .refused(.fail("expected areas as {x, y, w, h}"))
            }
            areas.append(
                ScreenArea(
                    id: fields["id"]?.intValue ?? index,
                    x: x,
                    y: y,
                    w: w,
                    h: h,
                    name: fields["name"]?.stringValue
                )
            )
        }
        return .split(
            ScreenSplit(areas: areas, nextID: previous?.nextID)
        )
    }

    private func areaNameTaken(
        _ name: String,
        except key: ScreenAreaKey
    ) -> Bool {
        tiler.settings.displayAreas.contains { fingerprint, split in
            split.areas.contains {
                $0.name == name
                    && ScreenAreaKey(fingerprint: fingerprint, areaID: $0.id)
                        != key
            }
        } || state.workspaces.allDisplays.contains { $0.name == name }
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
        case .mixedAxes:
            "areas must all run side by side or all stacked"
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
    /// name if any, and its rect in the screen's own points.
    func areasJSON(of display: Display) -> JSONValue {
        guard let split = tiler.settings.displayAreas[display.fingerprint]
        else { return .array([]) }
        return .array(
            ScreenArea.readingOrder(split.areas).map { area in
                .object([
                    "key": .string(
                        ScreenAreaKey(
                            fingerprint: display.fingerprint,
                            areaID: area.id
                        ).description
                    ),
                    "name": area.name.map(JSONValue.string) ?? .null,
                    "x": .number(Double(area.x)),
                    "y": .number(Double(area.y)),
                    "w": .number(Double(area.w)),
                    "h": .number(Double(area.h)),
                ])
            }
        )
    }
}
