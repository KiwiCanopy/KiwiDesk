import Foundation

/// What KiwiVision draws: the plain settings, or a lens's over
/// them (#2103 ruling 23). The one door every Core read of a
/// KiwiVision setting takes (`VisionLookSeamTests`), so a lens
/// overrides each setting in one place.
public struct VisionLook: Equatable, Sendable {
    public var dim: Double
    public var blur: Bool
    public var appearance: VisionAppearance
    public var clearWallpaper: Bool
    public var clearApp: Bool
    /// Never dimmed: always the plain list (ruling 33).
    public var neverDimmed: [String]
    /// The lens drawn, nil for plain KiwiVision.
    public var lens: VisionLens?

    /// Every app this look names as clear by listing it — Never
    /// dimmed and the lens's members: the one derivation the
    /// bundle read and the list's freshness key on.
    public var listedApps: [String] {
        neverDimmed + (lens?.apps ?? [])
    }
}

extension AppWideSettings {
    /// The look for `lens`, by name ignoring case; plain where the
    /// name is nil or names no lens.
    public func look(lens name: String?) -> VisionLook {
        let lens = name.flatMap { lens(named: $0) }
        let overrides = lens?.overrides ?? VisionLens.Overrides()
        return VisionLook(
            dim: overrides.dim ?? visionDim,
            blur: overrides.blur ?? visionBlur,
            appearance: overrides.appearance ?? visionAppearance,
            clearWallpaper: overrides.clearWallpaper
                ?? visionClearWallpaper,
            clearApp: overrides.clearApp ?? visionClearApp,
            neverDimmed: visionNeverDimmed,
            lens: lens
        )
    }

    /// The lens named `name`, ignoring case (ruling 39).
    public func lens(named name: String) -> VisionLens? {
        let name = Self.lensName(name)
        return visionLenses.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }
}
