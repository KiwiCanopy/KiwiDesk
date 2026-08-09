import Foundation
import Testing

@testable import KiwiDesk

/// The palette shelf's card chrome and its applied mark (#757).
///
/// Every assertion here is a needle on a USE site in
/// whitespace-squashed, comment-stripped source — the Monitors
/// idiom, for the Monitors reason: an applied mark is a
/// SURFACING branch, so nothing it draws survives into a value a
/// unit test can read. `ColorPaletteMatchTests` proves the answer
/// is right; only a scan can prove the view asked for it and drew
/// it.
@Suite("Palette shelf chrome")
struct PaletteShelfChromeTests {
    private var colorsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors"
            )
    }

    private func squashed(_ file: String) throws -> String {
        let source = try String(
            contentsOf: colorsDir.appendingPathComponent(file),
            encoding: .utf8
        )
        // A file that vanished would otherwise make every needle
        // below pass by throwing nothing to look at.
        #expect(source.count > 200, Comment(rawValue: file))
        return SourceScan.stripComments(source)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// The shelf asks the palette whether it is the applied one,
    /// against the STAGED config — asking the saved one would
    /// mark a card the draft has already moved away from.
    @Test("the shelf computes the applied answer")
    func shelfComputesTheAppliedAnswer() throws {
        let shelf = try squashed("PaletteShelf.swift")
        // Three claims, because the answer is now computed in
        // two steps: the colours come from the config the page
        // is EDITING, they are extracted once per pass, and each
        // tile is asked against that one map. Keyed on the use
        // sites — the `liveColors` declaration alone would be
        // satisfied by a property nothing reads.
        #expect(
            shelf.contains(
                "ColorPaletteKeys.extract(from:model.config"
                    + ".settings)"
            ),
            Comment(
                rawValue:
                    "the shelf no longer reads the staged "
                    + "config's colours"
            )
        )
        #expect(shelf.contains("letlive=liveColors"))
        #expect(
            shelf.contains("palette.isApplied(matching:live)"),
            Comment(
                rawValue:
                    "the tiles no longer ask which palette is "
                    + "applied"
            )
        )
        // VoiceOver's own answer, not only the glyph.
        #expect(
            shelf.contains(
                ".accessibilityAddTraits(applied?[.isSelected]:[])"
            )
        )
    }

    /// The tile draws BOTH arms — a branch that resolves the
    /// answer and then draws one frame regardless is the exact
    /// defect this needle exists for, and the rest-weight token
    /// name is a substring of the applied one, so the needle is
    /// the whole ternary rather than either name.
    @Test("the frame draws both weights and both inks")
    func frameDrawsBothStates() throws {
        let tile = try squashed("PaletteTile.swift")
        #expect(
            tile.contains(
                "SettingsTheme.paletteCardStrokeApplied"
                    + ":SettingsTheme.paletteCardStroke"
            ),
            Comment(
                rawValue:
                    "the tile's frame no longer takes both "
                    + "weights from SettingsTheme"
            )
        )
        #expect(
            tile.contains(
                "AnyShapeStyle(SettingsTheme.accent)"
                    + ":AnyShapeStyle(SettingsTheme.hairline)"
            ),
            Comment(
                rawValue:
                    "the applied frame no longer switches ink "
                    + "between accent and hairline"
            )
        )
        // The mark itself, and the slot that keeps names aligned
        // when it is absent.
        #expect(tile.contains("opacity(isApplied?1:0)"))
        #expect(
            tile.contains("L(\"palettes.applied\",\"Applied\")")
        )
        #expect(tile.contains(".accessibilityHidden(!isApplied)"))
        // The add tile's label is the diff's other newly-authored
        // accessibility name, and it had no needle beside its
        // twin. Its button draws no text of its own — the label
        // lives inside the plate — so dropping this leaves
        // VoiceOver deriving a name from whatever the plate
        // happens to contain.
        let shelf = try squashed("PaletteShelf.swift")
        #expect(
            shelf.contains(".accessibilityLabel(saveCurrentLabel)")
        )
    }

    /// Both tiles render through `PaletteTile`, which is what
    /// makes the add tile the same height as its neighbours
    /// instead of the same height by coincidence. The shelf
    /// therefore draws no frame of its own.
    @Test("both tiles share one frame")
    func bothTilesShareOneFrame() throws {
        let shelf = try squashed("PaletteShelf.swift")
        #expect(shelf.contains("PaletteTile(name:palette.name,"))
        // The add tile's own call, keyed on the argument that
        // makes it the add tile — its name is blank, and
        // squashing the source eats the space inside `" "`.
        #expect(shelf.contains("dashed:true)"))
        // Exactly the two: a third tile shape drawn inline is
        // what this suite exists to stop.
        #expect(
            shelf.components(separatedBy: "PaletteTile(").count
                == 3
        )
        // Every way a view can draw a frame, not just the one
        // `PaletteTile` happens to use: a guard-prover run put a
        // third tile shape in the user grid with `.stroke(` and
        // a different radius, and a needle on `.strokeBorder(`
        // alone did not see it.
        for shape in [
            ".strokeBorder(", ".stroke(", ".border(",
        ] {
            #expect(
                !shelf.contains(shape),
                Comment(
                    rawValue:
                        "the shelf draws a tile frame "
                        + "(`\(shape)`) beside PaletteTile's — "
                        + "the two will drift"
                )
            )
        }
    }

    /// The one place the app's chrome may not go. The shelf's
    /// content IS colour, so an accent mark laid on a palette's
    /// own picture is invisible against the palettes whose hue it
    /// happens to share — Kiwi Neon's `#86EA43` against the
    /// theme's `#8DB354` — and rescuing it needs a halo over a
    /// composite, which is the trap #758 paid for.
    @Test("no mark and no accent land on the palette's picture")
    func thumbnailStaysThePalettes() throws {
        let thumb = try squashed("PaletteSceneThumbnail.swift")
        for forbidden in [
            "checkmark", "SettingsTheme.accent",
        ] {
            #expect(
                !thumb.contains(forbidden),
                Comment(
                    rawValue:
                        "the scene thumbnail draws `\(forbidden)` "
                        + "— app chrome on a picture whose "
                        + "content is the palette's own colour"
                )
            )
        }
    }

    /// `.secondary` is HIERARCHICAL — derived from the enclosing
    /// foreground — so one container-level `foregroundStyle` on
    /// the new card would silently retint the shelf's greys.
    /// Concrete inks instead, which is gui.md's rule and the
    /// reason these three files were converted with the card.
    @Test("no hierarchical grey survives in the shelf")
    func tilesUseConcreteInks() throws {
        // Both spellings. The needle was `Color.secondary`
        // alone, which is the spelling the tree does NOT use:
        // `.foregroundStyle(.secondary)` is idiomatic, was
        // shipping on two rows of this very file, and the guard
        // was green over its own violation.
        for file in [
            "PaletteShelf.swift", "PaletteShelf+Popovers.swift",
            "PaletteTile.swift", "PaletteSceneThumbnail.swift",
        ] {
            let source = try squashed(file)
            for ink in [".secondary", ".tertiary"] {
                #expect(
                    !source.contains(ink),
                    Comment(
                        rawValue:
                            "\(file) paints with `\(ink)`, which "
                            + "is derived from the enclosing "
                            + "foreground — the card is now that "
                            + "enclosure"
                    )
                )
            }
        }
    }
}
