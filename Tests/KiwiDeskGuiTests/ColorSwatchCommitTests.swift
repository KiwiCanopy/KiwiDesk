import Testing

@testable import KiwiDesk

/// A colour field's commit writes only an edit (#1857): a blur
/// that names the colour already stored writes nothing, so a well
/// whose binding writes several rows does not repaint them when
/// focus merely passes through, and a stored spelling is not
/// respelled into a dirty draft.
@Suite("Colour field commit")
struct ColorSwatchCommitTests {
    @Test("a commit of the stored colour writes nothing")
    func sameColourWritesNothing() {
        for draft in ["#8DB354", "#8db354", "8DB354", "#8DB354FF"] {
            #expect(
                ColorSwatch.committed(
                    draft: draft,
                    over: "#8DB354",
                    automatic: false
                ) == nil,
                "\(draft)"
            )
        }
    }

    @Test("an edit writes the normalised colour")
    func editWrites() {
        #expect(
            ColorSwatch.committed(
                draft: "#2f7fd6",
                over: "#8DB354",
                automatic: false
            ) == "#2F7FD6"
        )
        #expect(
            ColorSwatch.committed(
                draft: "#2F7FD680",
                over: "#2F7FD6",
                automatic: false
            ) == "#2F7FD680"
        )
        #expect(
            ColorSwatch.committed(
                draft: "nope",
                over: "#8DB354",
                automatic: false
            ) == nil
        )
    }

    @Test("clearing an Automatic field writes Automatic once")
    func automaticClears() {
        #expect(
            ColorSwatch.committed(
                draft: " ",
                over: "#8DB354",
                automatic: true
            ) == ""
        )
        #expect(
            ColorSwatch.committed(draft: "", over: "", automatic: true)
                == nil
        )
    }
}
