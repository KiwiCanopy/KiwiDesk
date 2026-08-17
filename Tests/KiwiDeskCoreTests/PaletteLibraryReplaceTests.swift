import Foundation
import Testing

@testable import KiwiDeskCore

/// `PaletteStore.replaceUserPalettes` on its own terms (#606).
///
/// It has one production caller, inside `restoreSetup`, and a
/// `guard-prover` round found that caller unable to prove the
/// method's riskiest half: making it **merge** —
/// `write(userPalettes() + admissible)` — left all 18 backup tests
/// green, because the restore's discard loop has already deleted
/// `palettes.json` by the time it runs, so there is nothing left
/// to merge with (2026-08-17).
///
/// The name says *replace*, so the replacing is what needs a net,
/// and it needs one here rather than through a caller that happens
/// to hide it.
@Suite("The palette library replaces wholesale (#606)")
@MainActor
struct PaletteLibraryReplaceTests {
    private func palette(
        _ name: String,
        hex: String = "#112233"
    ) -> ColorPalette {
        ColorPalette(
            name: name,
            colors: [ColorPaletteKeys.all[0]: hex]
        )
    }

    @Test("What was in the library is gone, not merged with")
    func replacesRatherThanMerges() throws {
        let core = makeTestCore()
        try core.paletteLibrary.save(palette("Old One"))
        try core.paletteLibrary.save(palette("Old Two"))

        try core.paletteLibrary.replaceUserPalettes(
            with: [palette("New")]
        )

        // A merge would answer three. The distinction is invisible
        // through `restoreSetup`, which deletes the file first.
        #expect(
            core.paletteLibrary.userPalettes().map(\.name) == ["New"]
        )
    }

    @Test("Replacing with nothing empties the library")
    func replacingWithNothingEmpties() throws {
        let core = makeTestCore()
        try core.paletteLibrary.save(palette("Old"))

        try core.paletteLibrary.replaceUserPalettes(with: [])

        // The edge a merge would also get wrong, and the one a
        // restore from a palette-free backup takes.
        #expect(core.paletteLibrary.userPalettes().isEmpty)
    }

    @Test("It reports how many it refused")
    func reportsWhatItDropped() throws {
        let core = makeTestCore()
        let builtin = try #require(
            core.paletteLibrary.builtins().first?.name
        )

        let dropped = try core.paletteLibrary.replaceUserPalettes(
            with: [palette(builtin), palette("Fine")]
        )

        // The count is the method's only way of saying it silently
        // refused something; a caller that ever wants to tell the
        // user needs it to be true.
        #expect(dropped == 1)
        #expect(
            core.paletteLibrary.userPalettes().map(\.name)
                == ["Fine"]
        )
    }

    @Test("Order is the incoming order, not the old one")
    func keepsTheIncomingOrder() throws {
        let core = makeTestCore()
        try core.paletteLibrary.save(palette("Z"))

        try core.paletteLibrary.replaceUserPalettes(
            with: [palette("B"), palette("A")]
        )

        // The shelf renders in saved order, so a restore that
        // re-sorted would silently rearrange the user's library.
        #expect(
            core.paletteLibrary.userPalettes().map(\.name)
                == ["B", "A"]
        )
    }
}
