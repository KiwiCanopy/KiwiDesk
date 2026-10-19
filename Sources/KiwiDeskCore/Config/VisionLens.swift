import Foundation

/// A KiwiVision lens (#2103 rulings 28–43): a named KiwiVision with
/// the apps it keeps clear, stored app-wide in `gui.json`'s
/// `kiwivision.lenses`. An override left out follows the plain
/// settings; Never dimmed is never a lens's to override.
public struct VisionLens: Equatable, Sendable {
    /// Unique ignoring case (ruling 39).
    public var name: String
    /// Member apps, each `AppRef.listKey`: a lowercased bundle id,
    /// or the process name of an app without one (ruling 31).
    public var apps: [String] = []
    /// Per member, the title fragments its clear windows match;
    /// a member left out keeps all its windows clear (ruling 32).
    public var titles: [String: [String]] = [:]
    /// "Keep focus on these apps", on by default (ruling 30).
    public var keepFocus = true
    /// Seconds another app's window waits before it clears; never
    /// below 0 (ruling 12).
    public var clearDelay: Double = 2
    /// The reminder shown while a window waits; nil shows the
    /// default phrase.
    public var reminder: String?
    public var overrides = Overrides()

    public init(name: String) { self.name = name }

    /// The plain settings a lens may override (ruling 23). Its
    /// fields mirror `AppWideSettings.Vision`'s, less Never dimmed
    /// and the lenses (`VisionLensTests` ▸ `overrideParity`).
    public struct Overrides: Equatable, Sendable {
        public var dim: Double?
        public var blur: Bool?
        public var appearance: VisionAppearance?
        public var fadeDuration: Int?
        public var fadeCurve: VisionFadeCurve?
        public var clearWallpaper: Bool?
        public var clearApp: Bool?
    }
}

extension VisionLens: Codable {
    /// One flat object per lens: its own keys and the overrides
    /// beside them, each named as the plain setting it overrides.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case name, apps, titles, reminder
        case keepFocus = "keep_focus"
        case clearDelay = "clear_delay"
        case dim, blur, appearance
        case fadeDuration = "fade_duration"
        case fadeCurve = "fade_curve"
        case clearWallpaper = "clear_wallpaper"
        case clearApp = "clear_app"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        apps = AppWideSettings.neverDimmedEntries(
            try c.decodeIfPresent([String].self, forKey: .apps) ?? []
        )
        titles = Self.memberTitles(
            try c.decodeIfPresent(
                [String: [String]].self,
                forKey: .titles
            ) ?? [:],
            of: apps
        )
        let defaults = VisionLens(name: name)
        keepFocus =
            try c.decodeIfPresent(Bool.self, forKey: .keepFocus)
            ?? defaults.keepFocus
        clearDelay = AppWideSettings.clampedDelay(
            try c.decodeIfPresent(Double.self, forKey: .clearDelay)
                ?? defaults.clearDelay
        )
        reminder = try c.decodeIfPresent(String.self, forKey: .reminder)
        overrides = Overrides(
            dim: try c.decodeIfPresent(Double.self, forKey: .dim)
                .map(AppWideSettings.clampedDim),
            blur: try c.decodeIfPresent(Bool.self, forKey: .blur),
            appearance: try c.decodeIfPresent(
                VisionAppearance.self,
                forKey: .appearance
            ),
            // A Lua table's numbers arrive as doubles.
            fadeDuration: try c.decodeIfPresent(
                Double.self,
                forKey: .fadeDuration
            ).map(AppWideSettings.clampedFade),
            fadeCurve: try c.decodeIfPresent(
                VisionFadeCurve.self,
                forKey: .fadeCurve
            ),
            clearWallpaper: try c.decodeIfPresent(
                Bool.self,
                forKey: .clearWallpaper
            ),
            clearApp: try c.decodeIfPresent(Bool.self, forKey: .clearApp)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(apps, forKey: .apps)
        if !titles.isEmpty { try c.encode(titles, forKey: .titles) }
        try c.encode(keepFocus, forKey: .keepFocus)
        try c.encode(clearDelay, forKey: .clearDelay)
        try c.encodeIfPresent(reminder, forKey: .reminder)
        try c.encodeIfPresent(overrides.dim, forKey: .dim)
        try c.encodeIfPresent(overrides.blur, forKey: .blur)
        try c.encodeIfPresent(overrides.appearance, forKey: .appearance)
        try c.encodeIfPresent(
            overrides.fadeDuration,
            forKey: .fadeDuration
        )
        try c.encodeIfPresent(overrides.fadeCurve, forKey: .fadeCurve)
        try c.encodeIfPresent(
            overrides.clearWallpaper,
            forKey: .clearWallpaper
        )
        try c.encodeIfPresent(overrides.clearApp, forKey: .clearApp)
    }
}

extension VisionLens {
    /// The keys a lens table takes, in `CodingKeys`' order: what
    /// `define_lens` reads and `kiwivision.current` returns.
    public static var tableKeys: [String] {
        CodingKeys.allCases.map(\.rawValue)
    }

    /// The key a profile's `lens_reach` names a lens by: its stored
    /// name, lowercased, since names are unique ignoring case
    /// (ruling 39).
    public static func reachKey(_ name: String) -> String {
        AppWideSettings.lensName(name).lowercased()
    }

    /// Title patterns keyed as members are (`AppRef.listKey`,
    /// trimmed and lowercased), a key naming no member dropped:
    /// a title rule only narrows a member (ruling 32).
    static func memberTitles(
        _ raw: [String: [String]],
        of members: [String]
    ) -> [String: [String]] {
        var out: [String: [String]] = [:]
        for (key, patterns) in raw {
            let member = key.trimmingCharacters(in: .whitespaces)
                .lowercased()
            guard members.contains(member) else { continue }
            out[member, default: []] += patterns
        }
        return out
    }
}

extension AppWideSettings {
    /// A lens's clear delay as stored: never below 0, a value that
    /// is no number the default 2 s.
    public static func clampedDelay(_ raw: Double) -> Double {
        raw.isFinite ? max(raw, 0) : VisionLens(name: "").clearDelay
    }

    /// The longest a lens name may be (ruling 39).
    public static let lensNameLimit = 40

    /// A lens name as stored and looked up: trimmed, and cut to
    /// `lensNameLimit` characters.
    public static func lensName(_ raw: String) -> String {
        String(
            raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(lensNameLimit)
        )
    }

    /// A lens list as stored: each name trimmed, a nameless lens
    /// and a later one whose name repeats an earlier one ignoring
    /// case dropped (ruling 39).
    public static func lensEntries(_ raw: [VisionLens]) -> [VisionLens] {
        var seen: Set<String> = []
        return raw.compactMap { lens in
            var lens = lens
            lens.name = lensName(lens.name)
            guard !lens.name.isEmpty,
                seen.insert(lens.name.lowercased()).inserted
            else { return nil }
            return lens
        }
    }
}
