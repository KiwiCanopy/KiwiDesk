import Foundation

/// Fills the Space switch plates' Liquid Glass leaf #1956 added,
/// in a file below the floor, from the one switch's agreement over
/// the four leaves the file already carries — the #1620/#1621
/// step's shape (`SpaceSwitchGlassMigrationTests`). Absent, it
/// would decode ON beside surfaces the user set off, and the switch
/// would open reading "differ" on a plain upgrade.
extension ConfigMigration {
    /// Spelled here rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let spaceSwitchGlassGroups = ["space_switch"]
    /// The switch's leaves before this one, by the older steps'
    /// own constants where they have one.
    static let spaceSwitchGlassSources =
        overlayGlassSources + overlayGlassGroups
    /// The formats this step introduced, a profile's and a bundle's.
    static let spaceSwitchGlassProfileFormat = 16
    static let spaceSwitchGlassBundleFormat = 21

    @Sendable
    static func migratingAbsentSpaceSwitchGlass(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: spaceSwitchGlassProfileFormat,
                bundle: spaceSwitchGlassBundleFormat
            )
        else { return nil }
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(glassSettingsKey)\"".utf8))
                    != nil
            },
            rewriting: {
                withGlass(
                    $0,
                    groups: spaceSwitchGlassGroups,
                    sources: spaceSwitchGlassSources
                )
            },
            editing: {
                surgicallyFilledGlass(
                    $0,
                    groups: spaceSwitchGlassGroups,
                    sources: spaceSwitchGlassSources
                )
            }
        )
    }
}
