import Foundation
import Testing

@testable import KiwiDesk

/// The palette naming popovers seed themselves (#843).
///
/// The defect this suite exists for is **presentation timing**,
/// which nothing headless can observe: the field showed a valid
/// name while the confirm button, evaluated against the view
/// value SwiftUI captured at presentation, read the empty
/// `@State` behind it and stayed disabled. So the guard is in
/// two halves, and neither is the screen:
///
/// 1. the validity rules are functions of a TYPED name, so they
///    can be asked about a name no shelf state ever held — which
///    is what makes the popover able to own its own;
/// 2. a source check that neither call site re-introduces the
///    write-then-present pair, since that pair is the defect and
///    it reads as ordinary SwiftUI.
///
/// Stated limit: a green here says the seed cannot be stale, not
/// that the button is drawn enabled — that half is device QA's,
/// and it is how this was found.
@Suite("Palette name popover seeding (#843)")
@MainActor
struct PaletteNameSeedTests {
    /// Through the shared factory, never a bare
    /// `SettingsModel(` — `MachineTouchTests` pins every
    /// construction in this tree to it, so a forgotten one
    /// writes the developer's real defaults.
    private func shelf() -> PaletteShelf {
        PaletteShelf(model: makeTestModel())
    }

    /// The rule the disabled button was answering wrongly. Asked
    /// of the name directly, a freshly seeded one is valid — so
    /// the first open of a visit has nothing to fix.
    @Test("a freshly seeded name is immediately saveable")
    func seededNameIsValid() {
        let view = shelf()
        let seed = view.nextUserName()
        #expect(!seed.isEmpty)
        #expect(view.canSave(seed))
        // And the empty name the stale snapshot carried is
        // exactly what the rule refuses — which is why the
        // button read as disabled rather than as broken.
        #expect(!view.canSave(""))
        #expect(!view.canSave("   "))
    }

    /// A rename may keep its own name; a save may not silently
    /// take an existing one. The two rules differ, which is why
    /// the popover takes the rule as a parameter rather than
    /// re-deriving one.
    @Test("rename accepts its own name, save refuses a built-in")
    func theTwoRulesDiffer() throws {
        let view = shelf()
        // A bundled palette always exists; requiring it keeps
        // the two assertions below from passing vacuously on an
        // empty list.
        let builtin = try #require(
            view.store.builtins().first?.name
        )
        #expect(view.canRename("Anything", from: "Anything"))
        #expect(!view.canRename("", from: "Anything"))
        #expect(!view.canSave(builtin))
        #expect(!view.canRename(builtin, from: "Anything"))
    }

    /// Neither call site writes the name it is about to present.
    /// This is the needle for the defect itself: the seed must
    /// come from a value in scope — `nextUserName()` computed
    /// inside the popover, the palette's own name — never from
    /// shelf `@State` set in the same tick as `savingCurrent` or
    /// `renaming`.
    @Test("no call site seeds shelf state before presenting")
    func seedsAreNotWrittenIntoShelfState() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors"
            )
        for name in [
            "PaletteShelf.swift", "PaletteShelf+Popovers.swift",
        ] {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(name),
                    encoding: .utf8
                )
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            for banned in ["saveName=", "renameDraft="] {
                #expect(
                    !source.contains(banned),
                    Comment(
                        rawValue:
                            "\(name) writes `\(banned)` — a name "
                            + "seeded into shelf state one tick "
                            + "before the popover is presented "
                            + "is read as EMPTY by the confirm "
                            + "button's .disabled, which is #843. "
                            + "Pass the seed to "
                            + "PaletteNamePopover instead."
                    )
                )
            }
        }
        // And the popover really does own it.
        let popover = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "PaletteNamePopover.swift"
                ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            popover.contains("_name=State(initialValue:seed)")
        )
    }
}
