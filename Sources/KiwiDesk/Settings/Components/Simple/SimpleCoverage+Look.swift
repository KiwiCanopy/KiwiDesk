import KiwiDeskCore

/// Which census rows a look paints (#2737 ruling 12): the Look line
/// wrote them, so their rows stay on Simple. Read off the look's own
/// paths — `LookKeys.all`, a saved look's animations included, and
/// `ColorPaletteKeys.all` — never a list of areas, which kept
/// visibility rows a look never touches.
extension SimpleCoverage {
    static func isLookPainted(_ key: SettingKey) -> Bool {
        guard let path = wirePath(ofCensusID: key.id) else {
            return false
        }
        return lookPaths.contains {
            path == $0 || path.hasPrefix($0 + ".")
        }
    }

    private static let lookPaths = Set(
        LookKeys.all + ColorPaletteKeys.all
    )

    /// The census id's settings path in the wire spelling a look
    /// stores: `settings.borderStyle.cornerStyle` reads
    /// `border.corner_style`, `settings.gapsGlobal.outer.top` reads
    /// `gap.global.outer.top`. Nil for an id outside `settings.`.
    static func wirePath(ofCensusID id: String) -> String? {
        let bare = id.split(separator: " ").first.map(String.init) ?? id
        guard bare.hasPrefix("settings.") else { return nil }
        var parts = bare.dropFirst("settings.".count)
            .split(separator: ".").map(String.init)
        guard let head = parts.first else { return nil }
        let groups = [
            "kiwishelf": "kiwishelf", "borderStyle": "border",
            "spaceBarStyle": "space_bar", "appBarStyle": "app_bar",
            "gapsGlobal": "gap.global", "animations": "animations",
            "dragGhost": "drag.ghost", "dragDropZone": "drag.drop_zone",
            "stickyStyle": "sticky", "floatingStyle": "floating",
            "pocketStyle": "pocket",
        ]
        guard let group = groups[head] else { return nil }
        parts.removeFirst()
        return ([group] + parts.map(snake)).joined(separator: ".")
    }

    /// A Swift name's wire spelling. A millisecond store drops
    /// its `MS` on the wire (`durationMS` reads `duration`), which
    /// `SimpleSectionsTests` ▸ `lookPathsAreMatched` holds.
    private static func snake(_ camel: String) -> String {
        let bare = camel.hasSuffix("MS") ? String(camel.dropLast(2)) : camel
        return bare.reduce(into: "") { out, char in
            if char.isUppercase, !out.isEmpty { out += "_" }
            out += char.lowercased()
        }
    }
}
