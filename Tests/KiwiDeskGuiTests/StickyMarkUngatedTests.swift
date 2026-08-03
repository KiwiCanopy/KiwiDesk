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
/// precisely what survives the bar going. Greying says *turn
/// that on and I act*, and a census `gate:` records the same
/// claim as data for whatever reads the census, so the row
/// carries neither. It is dropped rather than softened, with
/// the fact moved into the row's `?` help; the argument is in
/// `docs/design-decisions.md` under "Sticky has no native cue".
///
/// So this is a **retired-coupling** scan (tests.md, Removal):
/// nothing else would notice the gate coming back. Three ways
/// it could, one assertion each — the census declaration, the
/// greying in the editor itself, and the write-through that used
/// to keep a forced-ON toggle honest by storing what it
/// displayed.
///
/// The census has TWO gate axes and a row is greyed by either,
/// so both are asserted: a container gate on `.stickyWindows`
/// re-greys this row exactly as a row gate would — it is not
/// `exemptFromContainerGate`. Reading one axis and calling the
/// census covered is how this suite passed its own worst
/// mutation (guard-prover, first cut).
///
/// **What it does not cover**, stated per test so it is not
/// mistaken for coverage:
///
/// - `editorHasNoGate` reads ONE file. A gate applied from the
///   COMPOSITION site — `GapsAndBordersSection` wrapping
///   `StickyMarkEditor(model:)` in a `GreyOut`, or passing a
///   `gatedOff:` in — is a fourth axis and is not netted here;
///   `ui-patterns.md`'s own block-gate convention pushes gates
///   there, so it is the likely spelling, not an exotic one.
///   It is left to review rather than scanned because the
///   section composes four editors and pinning its exact
///   spelling would red on any reordering of them.
/// - The needles cover the shape the gate had when it shipped
///   and the shape the house style would give it today (a
///   resolver answering `allowsEditing`). A third spelling —
///   `opacity` computed inline, a custom `ViewModifier` — is
///   not netted.
/// - `nothingWritesTheMark` nets ONE spelling: the field name
///   followed by `=` after whitespace packing. A `.toggle()`, a
///   keypath write, or a setter assigning through a local copy
///   of `settings` all pass green.
@Suite("The sticky mark's toggle is ungated")
struct StickyMarkUngatedTests {
    private var guiTree: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    /// The census declares the dependency as data, so it is the
    /// half worth asserting as a value rather than scanning for.
    @Test("the census row declares no gate")
    func censusRowIsUngated() {
        let placement = SettingKey.borders(.stickyMark).placement
        #expect(placement.gate == nil)
        // The row is still surfaced — an ungated row and a
        // deleted one are not the same fix.
        #expect(placement.area == .gapsAndBorders)
        #expect(placement.container == .stickyWindows)
        // The second axis. The row carries no
        // `exemptFromContainerGate`, so a gate on its container
        // greys it just as thoroughly and says the same false
        // thing.
        #expect(SettingsContainer.stickyWindows.gate == nil)
    }

    /// The editor greys nothing, reads nothing off the bar, and
    /// displays no value but the stored one.
    ///
    /// `containerReason` and `.constant(` are needles because the
    /// coupling does not have to come back in the spelling it
    /// left in: a resolver-routed grey is the house style for
    /// gates here (`BarsGates`), and the forced-ON ternary
    /// is separable from the greying — on its own it is the half
    /// that made the toggle misreport the stored value, which is
    /// worse than dimming it.
    @Test("the editor carries no Space Bar gate")
    func editorHasNoGate() throws {
        let source = try strippedSource(
            named: "StickyMarkEditor.swift"
        )
        let needles = [
            "spaceBarStyle", "GreyOut", ".disabled(",
            "containerReason", ".constant(",
        ]
        for needle in needles {
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
    ///
    /// `==` is excluded explicitly rather than left to fail
    /// shut. A READ of the field is legitimate and imminent —
    /// a census-rendered Gaps & Borders resolves gates by
    /// comparing settings — so a comparison must not red under
    /// a message that says "assigns".
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
            let after = packed.components(
                separatedBy: "stickyStyle.mark="
            )
            let assigns = after.dropFirst().contains {
                !$0.hasPrefix("=")
            }
            #expect(
                !assigns,
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
