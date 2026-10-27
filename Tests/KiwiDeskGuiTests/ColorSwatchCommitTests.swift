import Foundation
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
    @MainActor
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
    @MainActor
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

    /// The field writes only what `committed` answers: a call site
    /// that fell back to the stored hex would write it on every
    /// blur and repaint a role group's rows.
    @Test("the field writes only a committed value")
    func callSiteWritesOnlyAnAnswer() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "ColorField.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
            .filter { !$0.isWhitespace }
        #expect(source.contains("ifletvalue=Self.committed("))
        #expect(source.components(separatedBy: "Self.committed(").count == 2)
    }

    @Test("clearing an Automatic field writes Automatic once")
    @MainActor
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

    @Test("clearing a No Color field writes No Color once")
    @MainActor
    func clearableClears() {
        #expect(
            ColorSwatch.committed(
                draft: " ",
                over: "#2F7FD6CC",
                automatic: false,
                clearable: true
            ) == "#2F7FD600"
        )
        #expect(
            ColorSwatch.committed(
                draft: "",
                over: "#2F7FD600",
                automatic: false,
                clearable: true
            ) == nil
        )
        #expect(
            ColorSwatch.shown("#2F7FD600", clearable: true).isEmpty
        )
    }

    @Test("an empty field on a well with both flags writes Automatic")
    @MainActor
    func bothFlagsClearToAutomatic() {
        #expect(
            ColorSwatch.committed(
                draft: "",
                over: "#8DB354",
                automatic: true,
                clearable: true
            ) == ""
        )
    }
}
