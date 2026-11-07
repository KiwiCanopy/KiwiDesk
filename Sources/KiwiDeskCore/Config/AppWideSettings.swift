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
    /// How the scroll Space step shows itself
    /// (`space.scroll_transition`, #2971), apart from every other
    /// switch. The slide by default, whatever `spaceTransition` is.
    public var spaceScrollTransition = SpaceTransition.slide
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
