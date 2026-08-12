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
@Suite("Name popover seeding (#843)")
@MainActor
struct NameEditSeedTests {
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

    /// **A popover holding a text field is presented by ITEM,
    /// everywhere in Settings.** That is the structural form of
    /// #843: `.popover(isPresented:)` builds its content from the
    /// view value SwiftUI captured, so a seed written into
    /// `@State` in the same tick is read back as empty by
    /// anything that is not a `Binding` — which is how a valid
    /// name sat in the field over a dead confirm button.
    ///
    /// Scanned as a rule rather than as two property names: the
    /// first cut banned `saveName =` / `renameDraft =` in two
    /// files, and three more call sites had the identical shape
    /// (two of them merely latent, their gates refusing the
    /// stale value and the fresh one alike) — a needle keyed on
    /// today's spellings would have called that clean (code
    /// review, 2026-08-12).
    /// The one exemption, and why: a popover whose field starts
    /// EMPTY has no seed to be stale about. Its confirm is
    /// correctly dead until the user types, which is the same
    /// thing the defect looked like and is not it. Keyed by
    /// file, so a second popover in one of these files still has
    /// to be read by a human — which is how the layer strip's
    /// add-a-layer popover came to be checked at all.
    private let emptySeeded: [String: String] = [
        "LayerStripEditor.swift":
            "the add-a-layer popover names something that does "
            + "not exist yet, so it opens with an empty field "
            + "and a correctly disabled confirm — the RENAME "
            + "popover in this same file is presented by item"
    ]

    @Test("a popover with a text field is presented by item")
    func nameEditingPopoversPresentByItem() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        #expect(files.count > 50)
        for file in files {
            let name = file.lastPathComponent
            guard emptySeeded[name] == nil else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            for block in presentedBlocks(
                in: source,
                after: ".popover(isPresented:"
            )
            where block.contains("TextField(")
                || block.contains("NameEditPopover(")
            {
                Issue.record(
                    Comment(
                        rawValue:
                            "\(name) presents "
                            + "a name popover with "
                            + "`isPresented:`. Present it with "
                            + "`.popover(item:)` over a "
                            + "NameEditRequest so the seed "
                            + "reaches the builder — written "
                            + "into @State one tick earlier it "
                            + "is read back empty (#843)."
                    )
                )
            }
        }
    }

    /// The brace-balanced content of each `.popover(` whose head
    /// matches `marker`.
    private func presentedBlocks(
        in source: String,
        after marker: String
    ) -> [String] {
        var blocks: [String] = []
        var rest = Substring(source)
        while let hit = rest.range(of: marker) {
            let tail = rest[hit.upperBound...]
            guard let open = tail.firstIndex(of: "{") else {
                break
            }
            var depth = 0
            var body = ""
            for character in tail[open...] {
                if character == "{" { depth += 1 }
                if depth > 0 { body.append(character) }
                if character == "}" {
                    depth -= 1
                    if depth == 0 { break }
                }
            }
            blocks.append(body)
            rest = tail
        }
        return blocks
    }
}
