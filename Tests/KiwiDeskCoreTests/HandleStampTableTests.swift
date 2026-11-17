import Foundation
import Testing

@testable import KiwiDeskCore

/// What the handle stamp (#3409) spells as history: the paint it
/// applies and the palettes it matches, split from
/// `HandleStampMigrationTests` at the file ceiling.
@Suite("Handle stamp table (#3409)")
struct HandleStampTableTests {
    /// The step spells the paint as history; a new `bundledPaint`
    /// entry owes a crossing of its own (bars.md).
    @Test("the step's paint is the one bundledPaint entry")
    func paintIsBundledPaint() {
        #expect(
            ColorPaletteKeys.bundledPaint
                == [
                    ConfigMigration.handleStampPath:
                        ConfigMigration.handleStampSourcePath
                ]
        )
    }

    /// While the looks format is the one this step introduced, its
    /// frozen palettes are what this build ships; a later bump
    /// retires the clause, since the table is history from then on.
    @Test("the frozen palettes are the shipped ones")
    func frozenIsShipped() {
        guard
            LookDocument.currentFormat
                == ConfigMigration.handleStampLookFormat
        else { return }
        let shipped = PaletteCatalog.bundled()
        #expect(
            ConfigMigration.handleStampPalettes.map(\.name)
                == shipped.map(\.name)
        )
        for palette in shipped {
            let frozen = ConfigMigration.handleStampPalettes
                .first { $0.name == palette.name }?.colors
            #expect(frozen == palette.colors, "\(palette.name)")
        }
    }
}
