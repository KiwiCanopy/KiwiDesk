import Foundation
import Testing

@testable import KiwiDesk

/// The sticky-mark toggle stands alone, and this suite is what
/// keeps it that way.
///
/// It shipped greyed and forced ON while the Space Bar was off,
/// on the reasoning that the mark was then the only sticky cue
/// left. The fact is true; the DEPENDENCY it was expressed as
/// runs the other way — the mark paints on the window, so it is
/// precisely what survives the bar going. Under the #678
/// redesign a gated row generates its own caption, and this
/// one's would read "Needs the Space Bar · Bars": a statement
/// the app would contradict the moment a user hid the bar and
/// watched the marks stay. It is dropped rather than softened,
/// with the fact moved into the row's `?` help; the argument is
/// in `docs/design-decisions.md` under "Sticky state must never
/// be invisible from the GUI".
///
/// So this is a **retired-coupling** scan (tests.md, Removal):
/// nothing else would notice the gate coming back. Three ways
/// it could, one assertion each — the census declaration that
/// the redesign renders from, the greying in the editor itself,
/// and the write-through that used to keep a forced-ON toggle
/// honest by storing what it displayed.
///
/// What it does NOT cover, stated so it is not mistaken for
/// coverage: a gate re-introduced from OUTSIDE these two files —
/// a parent view greying the section, a resolver answering for
/// this row — is invisible here, as is any greying spelled
/// without the three needles below.
@Suite("The sticky mark's toggle is ungated")
struct StickyMarkUngatedTests {
    private var guiTree: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    /// The census is where a gate would become a rendered
    /// caption, so it is the half worth asserting as a value
    /// rather than scanning for.
    @Test("the census row declares no gate")
    func censusRowIsUngated() {
        let placement = SettingKey.borders(.stickyMark).placement
        #expect(placement.gate == nil)
        // The row is still surfaced — an ungated row and a
        // deleted one are not the same fix.
        #expect(placement.area == .gapsAndBorders)
        #expect(placement.container == .stickyWindows)
    }

    /// The editor greys nothing and reads nothing off the bar.
    @Test("the editor carries no Space Bar gate")
    func editorHasNoGate() throws {
        let source = try strippedSource(
            named: "StickyMarkEditor.swift"
        )
        for needle in ["spaceBarStyle", "GreyOut", ".disabled("] {
            #expect(
                !source.contains(needle),
                Comment(
                    rawValue:
                        "StickyMarkEditor gates on `\(needle)` — "
                        + "the mark outlives the Space Bar, so a "
                        + "gate on it states something false"
                )
            )
        }
    }

    /// Nothing in the Settings tree WRITES the mark. The Space
    /// Bar's own switch used to, forcing `mark = true` on its way
    /// off so the greyed toggle displayed the stored value rather
    /// than a fiction; with no greying there is nothing to keep
    /// honest, and a switch that silently rewrites another
    /// setting is the part a user cannot undo.
    ///
    /// Whitespace is stripped before matching so that `swift
    /// format` re-wrapping a long path cannot hide an assignment
    /// (`…settings\n.stickyStyle.mark = true` is one line to the
    /// compiler and two to a needle). The toggle's own binding
    /// carries no `=` and so does not match.
    @Test("no view writes the mark behind the user's back")
    func nothingWritesTheMark() throws {
        let files = try SourceScan.swiftSources(under: guiTree)
        // An enumerator over a missing directory yields nothing,
        // and a loop over nothing passes having looked at
        // nothing. This repo has shipped that.
        #expect(!files.isEmpty, "no GUI sources scanned")
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let packed = source.split(
                whereSeparator: \.isWhitespace
            ).joined()
            #expect(
                !packed.contains("stickyStyle.mark="),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) assigns "
                        + "stickyStyle.mark — the mark is the "
                        + "user's setting, not a side effect"
                )
            )
        }
    }

    private func strippedSource(named: String) throws -> String {
        let files = try SourceScan.swiftSources(under: guiTree)
        let file = try #require(
            files.first { $0.lastPathComponent == named },
            "\(named) is gone"
        )
        return SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
    }
}
