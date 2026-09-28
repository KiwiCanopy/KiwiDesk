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

    public init() {}

    /// `raw` clamped into the range the verb and the GUI enforce,
    /// so a hand-edited file cannot smuggle a value past it.
    static func clampedDepth(_ raw: Int) -> Int {
        let range = QuitGridLayout.targetDepthRange
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

    /// The stored value, or nil when neither group is present —
    /// the file predates #1741 and the crossing is still owed.
    init?(refusal: Refusal?, quit: Quit?) {
        guard refusal != nil || quit != nil else { return nil }
        self.init()
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
}
