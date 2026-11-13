import Foundation

/// `AppWideSettings` as `gui.json` stores it: one Codable group per
/// top-level key (#1741), and the two directions between them.
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
        var scrollTransition: SpaceTransition?
        var slideDuration: Int?

        enum CodingKeys: String, CodingKey {
            case transition
            case scrollTransition = "scroll_transition"
            case slideDuration = "slide_duration"
        }
    }

    /// `gui.json`'s app-wide `animations` group (#3237): the four
    /// lengths that left each profile's `animations`. Its absence is
    /// the crossing's signal (`KiwiCore.prepareAppWide`).
    struct Animations: Codable, Equatable {
        var duration: Int?
        var scrollDuration: Int?
        var expandDuration: Int?
        var revealDuration: Int?
        var reduceMotion: Bool?

        enum CodingKeys: String, CodingKey {
            case reduceMotion = "reduce_motion"
            case duration
            case scrollDuration = "scroll_duration"
            case expandDuration = "expand_duration"
            case revealDuration = "reveal_duration"
        }

        /// 4.2's four lengths, the meaning of their absence in a file
        /// from before the group (#3254).
        static var legacyDefaults: Self {
            let table = AnimationPacePreset.legacyDefaults
            return Self(
                duration: table.window,
                scrollDuration: table.scroll,
                expandDuration: table.expand,
                revealDuration: table.reveal
            )
        }
    }

    /// `gui.json`'s `mode` group (#2144) — additive, as `desktop`.
    struct Mode: Codable {
        var cue: Bool?
    }

    /// `gui.json`'s `tiling` group (#3008) — additive, as `desktop`;
    /// the two hide ticks' bases joined it with no crossing (#3089).
    struct Tiling: Codable {
        var startGlobal: Bool?
        var offHidesBorders: Bool?
        var offHidesBars: Bool?

        enum CodingKeys: String, CodingKey {
            case startGlobal = "start_global"
            case offHidesBorders = "off_hides_borders"
            case offHidesBars = "off_hides_bars"
        }
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
        /// Absent while Off (#3064), so it owes no crossing.
        var maximize: VisionMaximize?
        var neverDimmed: [String]?
        var lenses: [VisionLens]?

        enum CodingKeys: String, CodingKey {
            case dim, blur, appearance, lenses, maximize
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
        tiling: Tiling? = nil,
        vision: Vision? = nil,
        hyper: Hyper? = nil,
        kiwihub: KiwiHub? = nil,
        modifier: Modifier? = nil,
        animations: Animations? = nil
    ) {
        guard refusal != nil || quit != nil else { return nil }
        self.init()
        adoptPace(animations)
        if let cue = desktop?.cue { desktopCue = cue }
        if let transition = space?.transition {
            spaceTransition = transition
        }
        if let transition = space?.scrollTransition {
            spaceScrollTransition = transition
        }
        if let ms = space?.slideDuration {
            spaceSlideDuration = Self.clampedSlideDuration(ms)
        }
        if let cue = mode?.cue { modeCue = cue }
        if let start = tiling?.startGlobal { tilingStartGlobal = start }
        if let hides = tiling?.offHidesBorders {
            tilingOffHidesBorders = hides
        }
        if let hides = tiling?.offHidesBars { tilingOffHidesBars = hides }
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
        if let fill = vision?.maximize { visionMaximize = fill }
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
        Space(
            transition: spaceTransition,
            scrollTransition: spaceScrollTransition,
            slideDuration: spaceSlideDuration
        )
    }
    var mode: Mode { Mode(cue: modeCue) }
    var animations: Animations {
        Animations(
            duration: animationDurationMS,
            scrollDuration: animationScrollDurationMS,
            expandDuration: animationExpandDurationMS,
            revealDuration: animationRevealDurationMS,
            reduceMotion: animationReduceMotion
        )
    }

    /// `group`'s lengths, each through its setter's clamp; nil is a
    /// file from before the group, whose lengths are owed.
    mutating func adoptPace(_ group: Animations?) {
        guard let group else {
            animationPaceStored = false
            return
        }
        animationPaceStored = true
        if let ms = group.duration { animationDurationMS = ms }
        if let ms = group.scrollDuration { animationScrollDurationMS = ms }
        if let ms = group.expandDuration { animationExpandDurationMS = ms }
        if let ms = group.revealDuration { animationRevealDurationMS = ms }
        if let off = group.reduceMotion { animationReduceMotion = off }
    }
    var tiling: Tiling {
        Tiling(
            startGlobal: tilingStartGlobal,
            offHidesBorders: tilingOffHidesBorders,
            offHidesBars: tilingOffHidesBars
        )
    }
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
            maximize: visionMaximize == .off ? nil : visionMaximize,
            neverDimmed: visionNeverDimmed,
            lenses: visionLenses
        )
    }
}
