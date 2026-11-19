@testable import KiwiDeskCore

extension HandleStampMigrationTests {
    /// The handle the crossing stamps for Glass: its duty shade, as
    /// the frozen table holds it (#3514).
    static let glassHandle =
        ConfigMigration.handleStampPalettes[0].colors[
            "kiwishelf.handle_color"
        ]
}
