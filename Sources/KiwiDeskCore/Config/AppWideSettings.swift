import Foundation

/// Settings no profile carries (#1741): stored in `gui.json`, held
/// live on `KiwiCore.appWide`, and never touched by a profile
/// apply. `KiwiCore+AppWide` owns every write.
public struct AppWideSettings: Equatable, Sendable {
    /// Whether a refusal pill also sounds (`refusal.sound`,
    /// #1255). OFF by default: the pill is the primary cue.
    public var refusalSound = false
    /// The quit grid's windows per pile
    /// (`quit.grid_target_depth`, #281), inside
    /// `QuitGridLayout.targetDepthRange`.
    public var quitGridTargetDepth = QuitGridLayout.defaultTargetDepth
    /// Where windows are arranged on quit (`quit.layout`, #197).
    public var quitLayout: QuitLayoutStyle = .grid
    /// Whether KiwiDesk's own Desktop switch shows the plate
    /// naming the Desktop it landed on (`desktop.cue`, #2142).
    /// ON by default: the instant switch removed the slide that
    /// was the cue.
    public var desktopCue = true
    /// How an explicit Space switch shows itself
    /// (`space.transition`, #2524). The slide by default.
    public var spaceTransition = SpaceTransition.slide
    /// The plate slide's pace in ms (`space.slide_duration`,
    /// #1956), inside `spaceSlideDurationRange`.
    public var spaceSlideDuration = AppWideSettings.spaceSlideDefaultMS
    /// Whether `cycle_mode` shows the plate with the cycle list
    /// and the layout it landed on (`mode.cue`, #2144). ON by
    /// default: the press asked for it.
    public var modeCue = true
    /// KiwiVision's dim, in percent (`kiwivision.dim`, #2103) —
    /// 60 by default (ruling 10).
    public var visionDim: Double = 60
    /// Whether KiwiVision's plate blurs (`kiwivision.blur`,
    /// #2103). ON by default (ruling 10).
    public var visionBlur = true
    /// The system appearance asked for while KiwiVision is on
    /// (`kiwivision.appearance`, #2103 ruling 7).
    public var visionAppearance = VisionAppearance.unchanged
    /// How long the window focus leaves takes into the dim and the
    /// blur, in ms (`kiwivision.fade_duration`, #2417); 0 cuts.
    public var visionFadeDuration = 300
    /// The curve of that fade (`kiwivision.fade_curve`, #2417).
    public var visionFadeCurve = VisionFadeCurve.easeOut
    /// Whether KiwiVision leaves the wallpaper clear, dimming only
    /// the windows (`kiwivision.clear_wallpaper`, #2103 ruling 17).
    /// OFF by default: v1's whole-screen haze.
    public var visionClearWallpaper = false
    /// Whether KiwiVision keeps every window of the focused app
    /// clear, not only the focused one (`kiwivision.clear_app`,
    /// #2103 ruling 17). OFF by default: v1's one clear window.
    public var visionClearApp = false
    /// The apps whose windows KiwiVision never dims or blurs, each
    /// a lowercased bundle id or, for a process with none, its name
    /// (`kiwivision.never_dimmed`, #2103 ruling 26). Empty by
    /// default.
    public var visionNeverDimmed: [String] = []
    /// KiwiVision's lenses (`kiwivision.lenses`, #2103 v3), names
    /// unique ignoring case. Empty by default.
    public var visionLenses: [VisionLens] = []
    /// The key turned into the Hyper modifier, nil for none
    /// (`hyper.key`, #1870). Per install, never per profile: it
    /// remaps a physical key, and a profile can change on a swipe.
    public var hyperKey: HyperSourceKey?
    /// Lua's alternatives to KiwiHub's navigation keys
    /// (`kiwihub.key`, #2600). None by default.
    public var kiwiHubKeys = KiwiHubKeys()
    /// Whether shortcuts tell left and right modifiers apart
    /// (`modifier.sides`, #2601). Off by default: no keyboard tap.
    public var modifierSides = false

    public init() {}

    /// `raw` clamped into the range the verb and the GUI enforce,
    /// so a hand-edited file cannot smuggle a value past it.
    static func clampedDepth(_ raw: Int) -> Int {
        let range = QuitGridLayout.targetDepthRange
        return min(max(raw, range.lowerBound), range.upperBound)
    }

    /// The dim's band in percent: the verb, the decode and the
    /// Settings stepper all read it.
    public static let visionDimRange: ClosedRange<Double> = 0...100

    /// The slide's default pace in ms. Moving it moves a stored
    /// default and owes profiles.md's crossing question (#1369).
    public static let spaceSlideDefaultMS = 300
    /// The slide's band in ms: below it the strip is a jump; above
    /// it a switch outlasts the hand that pressed it.
    public static let spaceSlideDurationRange: ClosedRange<Int> = 150...1000

    /// `raw` clamped into `spaceSlideDurationRange`.
    static func clampedSlideDuration(_ raw: Int) -> Int {
        let band = spaceSlideDurationRange
        return min(max(raw, band.lowerBound), band.upperBound)
    }

    /// The fade's band in ms: the verb, the decode and the Settings
    /// stepper all read it.
    public static let visionFadeRange: ClosedRange<Int> = 0...1000

    /// `raw` ms clamped into `visionFadeRange` before it becomes an
    /// `Int`, which a huge value would trap; non-finite is the
    /// default. The one reading of a stored or verb value (#2417).
    static func clampedFade(_ raw: Double) -> Int {
        guard raw.isFinite else { return AppWideSettings().visionFadeDuration }
        let band = visionFadeRange
        let clamped = min(
            max(raw, Double(band.lowerBound)),
            Double(band.upperBound)
        )
        return Int(clamped.rounded())
    }

    /// The fade's band as the verb and the API record spell it.
    static var visionFadeBand: String {
        "\(visionFadeRange.lowerBound)-\(visionFadeRange.upperBound)"
    }

    /// A Never dimmed list as stored: each entry trimmed and
    /// lowercased — a bundle id matches as `AppRef` lowercases it,
    /// a process name likewise — empty and repeated ones dropped.
    public static func neverDimmedEntries(_ raw: [String]) -> [String] {
        var seen: Set<String> = []
        return raw.compactMap { entry in
            let key = entry.trimmingCharacters(in: .whitespaces)
                .lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else {
                return nil
            }
            return key
        }
    }

    /// `raw` clamped into `visionDimRange`, as `clampedDepth`.
    static func clampedDim(_ raw: Double) -> Double {
        guard raw.isFinite else { return AppWideSettings().visionDim }
        let range = visionDimRange
        return min(max(raw, range.lowerBound), range.upperBound)
    }
}

extension AppWideSettings {
    /// `gui.json`'s `refusal` group.
    struct Refusal: Codable {
        var sound: Bool?
    }

    /// `gui.json`'s `quit` group.
    struct Quit: Codable {
        var gridTargetDepth: Int?
        var layout: QuitLayoutStyle?

        enum CodingKeys: String, CodingKey {
            case gridTargetDepth = "grid_target_depth"
            case layout
        }
    }

    /// `gui.json`'s `desktop` group (#2142) — additive: a file
    /// written before it reads the default.
    struct Desktop: Codable {
        var cue: Bool?
    }

    /// `gui.json`'s `space` group (#2228, #2524) — additive, as
    /// `desktop`. Its #2228 `cue` crosses to `transition` once
    /// (`migratingSpaceCueOntoTransition`).
    struct Space: Codable {
        var transition: SpaceTransition?
        var slideDuration: Int?

        enum CodingKeys: String, CodingKey {
            case transition
            case slideDuration = "slide_duration"
        }
    }

    /// `gui.json`'s `mode` group (#2144) — additive, as `desktop`.
    struct Mode: Codable {
        var cue: Bool?
    }

    /// `gui.json`'s `hyper` group (#1870) — additive, as `desktop`.
    /// Off is stored as `"off"`, never left out, so the group
    /// always carries its one leaf. Strict: a key name this build
    /// does not know fails the decode, so a renamed
    /// `HyperSourceKey` owes a `ConfigMigration` step (§5).
    struct Hyper: Codable, Equatable {
        var key: HyperSourceKey?

        enum CodingKeys: String, CodingKey { case key }

        init(key: HyperSourceKey?) { self.key = key }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let name = try container.decodeIfPresent(
                String.self,
                forKey: .key
            )
            guard let name, name != "off" else {
                key = nil
                return
            }
            guard let named = HyperSourceKey(rawValue: name) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .key,
                    in: container,
                    debugDescription: "unknown Hyper key \(name)"
                )
            }
            key = named
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(key?.rawValue ?? "off", forKey: .key)
        }
    }

    /// `gui.json`'s `kiwihub` group (#2600) — additive, as
    /// `desktop`.
    struct KiwiHub: Codable, Equatable {
        var key: KiwiHubKeys?
    }

    /// `gui.json`'s `modifier` group (#2601) — additive, as
    /// `desktop`.
    struct Modifier: Codable, Equatable {
        var sides: Bool?
    }

    /// `gui.json`'s `kiwivision` group (#2103) — additive, as
    /// `desktop`; v3's lenses joined it with no crossing.
    struct Vision: Codable, Equatable {
        var dim: Double?
        var blur: Bool?
        var appearance: VisionAppearance?
        /// Read as a number: a Lua table's arrives as a double.
        var fadeDuration: Double?
        var fadeCurve: VisionFadeCurve?
        var clearWallpaper: Bool?
        var clearApp: Bool?
        var neverDimmed: [String]?
        var lenses: [VisionLens]?

        enum CodingKeys: String, CodingKey {
            case dim, blur, appearance, lenses
            case fadeDuration = "fade_duration"
            case fadeCurve = "fade_curve"
            case clearWallpaper = "clear_wallpaper"
            case clearApp = "clear_app"
            case neverDimmed = "never_dimmed"
        }
    }

    /// The stored value, or nil when neither #1741 group is
    /// present — the file predates #1741 and the crossing is still
    /// owed. The `desktop` (#2142), `space` (#2228), `mode`
    /// (#2144), `kiwivision` (#2103), `hyper` (#1870) and
    /// `kiwihub` (#2600) and `modifier` (#2601) groups crossed
    /// nothing, so they never
    /// decide that.
    init?(
        refusal: Refusal?,
        quit: Quit?,
        desktop: Desktop? = nil,
        space: Space? = nil,
        mode: Mode? = nil,
        vision: Vision? = nil,
        hyper: Hyper? = nil,
        kiwihub: KiwiHub? = nil,
        modifier: Modifier? = nil
    ) {
        guard refusal != nil || quit != nil else { return nil }
        self.init()
        if let cue = desktop?.cue { desktopCue = cue }
        if let transition = space?.transition {
            spaceTransition = transition
        }
        if let ms = space?.slideDuration {
            spaceSlideDuration = Self.clampedSlideDuration(ms)
        }
        if let cue = mode?.cue { modeCue = cue }
        hyperKey = hyper?.key
        if let keys = kiwihub?.key { kiwiHubKeys = keys }
        if let sides = modifier?.sides { modifierSides = sides }
        if let dim = vision?.dim { visionDim = Self.clampedDim(dim) }
        if let blur = vision?.blur { visionBlur = blur }
        if let appearance = vision?.appearance {
            visionAppearance = appearance
        }
        if let fade = vision?.fadeDuration {
            visionFadeDuration = Self.clampedFade(fade)
        }
        if let curve = vision?.fadeCurve { visionFadeCurve = curve }
        if let clear = vision?.clearWallpaper {
            visionClearWallpaper = clear
        }
        if let clear = vision?.clearApp { visionClearApp = clear }
        if let apps = vision?.neverDimmed {
            visionNeverDimmed = Self.neverDimmedEntries(apps)
        }
        if let lenses = vision?.lenses {
            visionLenses = Self.lensEntries(lenses)
        }
        if let sound = refusal?.sound { refusalSound = sound }
        if let depth = quit?.gridTargetDepth {
            quitGridTargetDepth = Self.clampedDepth(depth)
        }
        if let layout = quit?.layout { quitLayout = layout }
    }

    var refusal: Refusal { Refusal(sound: refusalSound) }
    var quit: Quit {
        Quit(gridTargetDepth: quitGridTargetDepth, layout: quitLayout)
    }
    var desktop: Desktop { Desktop(cue: desktopCue) }
    var space: Space {
        Space(transition: spaceTransition, slideDuration: spaceSlideDuration)
    }
    var mode: Mode { Mode(cue: modeCue) }
    var hyper: Hyper { Hyper(key: hyperKey) }
    var kiwihub: KiwiHub { KiwiHub(key: kiwiHubKeys) }
    var modifier: Modifier { Modifier(sides: modifierSides) }
    var vision: Vision {
        Vision(
            dim: visionDim,
            blur: visionBlur,
            appearance: visionAppearance,
            fadeDuration: Double(visionFadeDuration),
            fadeCurve: visionFadeCurve,
            clearWallpaper: visionClearWallpaper,
            clearApp: visionClearApp,
            neverDimmed: visionNeverDimmed,
            lenses: visionLenses
        )
    }
}
