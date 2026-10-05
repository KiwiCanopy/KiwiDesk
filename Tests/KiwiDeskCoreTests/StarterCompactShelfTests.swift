import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A short MAIN screen thins the starter's shelf (#1952): Glass and
/// the first-run profile carry it, the main screen alone decides,
/// and no preset does. The cut-off and the depth are argued on
/// `StarterSetup.compactMainHeight` / `compactThickness`.
@Suite("Starter shelf on a short main screen (#1952)", .serialized)
@MainActor
struct StarterCompactShelfTests {
    private let air13 = CGSize(width: 1470, height: 956)
    private let laptop16 = CGSize(width: 1728, height: 1117)
    private let screen27 = CGSize(width: 2560, height: 1440)

    private var compact: CGFloat { StarterSetup.compactThickness }
    private var standard: CGFloat { KiwiShelf().thickness }

    private func thickness(_ sizes: [CGSize]) -> CGFloat {
        StarterSetup.settings(sizes: sizes).kiwishelf.thickness
    }

    @Test("the compact depth is thinner and clears the floor")
    func compactIsThinner() {
        #expect(compact < standard)
        #expect(compact > KiwiShelf.minThickness)
    }

    @Test("the main screen decides, for every screen's shelf")
    func mainScreenDecides() {
        #expect(thickness([air13]) == compact)
        #expect(thickness([air13, screen27]) == compact)
        #expect(thickness([screen27, air13]) == standard)
        #expect(thickness([laptop16]) == standard)
        #expect(thickness([screen27]) == standard)
    }

    @Test("the cut-off is exclusive")
    func cutOffIsExclusive() {
        let edge = StarterSetup.compactMainHeight
        #expect(
            thickness([CGSize(width: 1600, height: edge)]) == standard
        )
        #expect(
            thickness([CGSize(width: 1600, height: edge - 1)])
                == compact
        )
    }

    @Test("Glass carries the compact shelf on a short main screen")
    func glassIsCompact() {
        let worn = LookBody(
            style: LookCatalog.defaultLook(sizes: [air13]).style,
            colors: [:]
        ).worn(over: TilingSettings())
        #expect(worn.kiwishelf.thickness == compact)
    }

    @Test("no preset thins its shelf")
    func presetsKeepTheDefault() {
        for preset in StandardProfiles.workflows {
            #expect(
                preset.settings(sizes: [air13]).kiwishelf.thickness
                    == standard,
                "\(preset.name)"
            )
        }
    }

    /// Drives the production order: `loadConfig` on an empty
    /// config directory reads the ledger before it seeds gui.json.
    @Test("first run seeds gui.json's shared look from Glass")
    func firstRunSeedsTheCompactLook() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-compact-\(UUID().uuidString)"
                )
        )
        #expect(!core.guiConfigStore.exists)
        core.state.apply(
            .displaysChanged([
                Display(
                    id: DisplayID(10),
                    name: "Air",
                    frame: CGRect(origin: .zero, size: air13)
                )
            ])
        )
        core.loadConfig()
        let look = try #require(core.guiConfigStore.load()?.look)
        #expect(
            look.worn(over: TilingSettings()).kiwishelf.thickness
                == compact
        )
        #expect(core.tiler.settings.kiwishelf.thickness == compact)
    }
}
