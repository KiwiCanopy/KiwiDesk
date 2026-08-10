import Foundation
import Testing

@testable import KiwiDesk

/// The responsive pass's ORDER (#678 turn 17a): the preview
/// goes first, then the row layout, then the chrome — and
/// controls never.
///
/// The suite exists because that order is the whole design and
/// nothing else can see it. Each band's own properties read
/// fine in isolation; what goes wrong is one of them moving to
/// a different threshold, so that a window sheds its chrome
/// while the preview still has a column, or the rows reflow
/// while the pill still floats over them. So the assertions
/// walk every supported width rather than sampling the
/// breakpoints, and state the order as implications between
/// the properties rather than as a table of expected values —
/// a table would be a second copy of the enum.
@Suite("Responsive order")
struct SettingsResponsiveOrderTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// Every width the window can actually be, plus a wide
    /// tail. The lower bound IS the hard minimum: below it the
    /// window does not resize, so a band for 719 pt would be a
    /// band nothing can reach.
    private var supportedWidths: [CGFloat] {
        stride(
            from: SettingsWidthClass.minimum,
            through: 1600,
            by: 1
        ).map { CGFloat($0) }
    }

    @Test("the bands are the digest's three breakpoints")
    func bandsAreTheBreakpoints() {
        #expect(SettingsWidthClass.panelBreakpoint == 1200)
        #expect(SettingsWidthClass.rowBreakpoint == 900)
        #expect(SettingsWidthClass.chromeBreakpoint == 820)
        #expect(SettingsWidthClass.minimum == 720)
        // Inclusive at the top of each band, so a window sized
        // exactly to a breakpoint keeps the fuller form.
        #expect(SettingsWidthClass.of(width: 1440) == .wide)
        #expect(SettingsWidthClass.of(width: 1200) == .wide)
        #expect(SettingsWidthClass.of(width: 1199) == .medium)
        #expect(SettingsWidthClass.of(width: 900) == .medium)
        #expect(SettingsWidthClass.of(width: 899) == .compact)
        #expect(SettingsWidthClass.of(width: 820) == .compact)
        #expect(SettingsWidthClass.of(width: 819) == .tight)
        #expect(SettingsWidthClass.of(width: 720) == .tight)
    }

    /// The order, as implications. Read the failure message as
    /// "this width sheds things in the wrong sequence".
    @Test("nothing is shed out of order, at any width")
    func theOrderHolds() {
        for width in supportedWidths {
            let band = SettingsWidthClass.of(width: width)
            // A docked preview means nothing after it has gone
            // yet: the preview is FIRST.
            if band.docksPanel {
                #expect(!band.stacksRows)
                #expect(!band.collapsesChrome)
            }
            // Collapsed chrome is LAST, so everything before it
            // has already gone.
            if band.collapsesChrome {
                #expect(band.stacksRows)
                #expect(!band.docksPanel)
            }
            // One threshold, not two spellings of 900.
            #expect(band.docksSavePill == band.stacksRows)
        }
    }

    /// Widening never takes something away. The nesting is
    /// what makes the order a ladder rather than four
    /// independent verdicts — a band that dropped the preview
    /// but kept a wider band's row axis would satisfy every
    /// implication above and still be incoherent.
    @Test("each band is a superset of the narrower one")
    func bandsNest() {
        for width in supportedWidths {
            let here = SettingsWidthClass.of(width: width)
            let wider = SettingsWidthClass.of(width: width + 1)
            #expect(!(here.docksPanel && !wider.docksPanel))
            #expect(!(wider.stacksRows && !here.stacksRows))
            #expect(
                !(wider.collapsesChrome && !here.collapsesChrome)
            )
            #expect(wider.homeColumnCap >= here.homeColumnCap)
        }
    }

    /// "Controls never", in the one form a test can hold: an
    /// area that HAS a preview always has exactly one way to
    /// it, whatever the width and whatever the user answered.
    /// A fourth state — no card and no offer — is the failure
    /// this totality forbids, and it is one deleted `else`
    /// away in a view.
    @Test("an offered preview always has exactly one form")
    func previewIsAlwaysReachable() {
        for width in supportedWidths {
            let band = SettingsWidthClass.of(width: width)
            for answer in [nil, true, false] as [Bool?] {
                let form = SettingsPreviewForm.at(
                    band,
                    shown: answer
                )
                #expect(SettingsPreviewForm.allCases.count == 3)
                // Docked is the wide band's, and it ignores the
                // answer — there is no close affordance on a
                // docked panel to produce one.
                #expect((form == .docked) == band.docksPanel)
                // The user's answer, where there is one, is
                // stated in its own terms rather than by
                // re-running the implementation's expression:
                // a test written from the code under it agrees
                // with that code's bugs.
                if !band.docksPanel, answer == true {
                    #expect(form == .floating)
                }
                if !band.docksPanel, answer == false {
                    #expect(form == .offer)
                }
            }
        }
    }

    /// The band defaults, stated once: the 1100 pt frame draws
    /// the card open and the 820 pt frame draws "Show preview"
    /// — the whole difference between the two narrow bands.
    @Test("only the medium band opens the card unasked")
    func mediumOpensTheCard() {
        #expect(
            SettingsPreviewForm.at(.medium, shown: nil)
                == .floating
        )
        #expect(
            SettingsPreviewForm.at(.compact, shown: nil) == .offer
        )
        #expect(
            SettingsPreviewForm.at(.tight, shown: nil) == .offer
        )
        // And the answer overrides the default in both
        // directions, which is what makes it one card rather
        // than two behaviours.
        #expect(
            SettingsPreviewForm.at(.medium, shown: false)
                == .offer
        )
        #expect(
            SettingsPreviewForm.at(.tight, shown: true)
                == .floating
        )
    }

    /// Home's column ladder: 4 · 3 · 2, capped per band, and
    /// never 1 — at the hard minimum the measured fit is 2, so
    /// a band naming 1 would name a step the window cannot
    /// reach. The floor is arithmetic over the shipped card
    /// band, not a restatement of it.
    @Test("home's column cap steps with the bands")
    func homeColumnCaps() {
        #expect(SettingsWidthClass.wide.homeColumnCap == 4)
        #expect(SettingsWidthClass.medium.homeColumnCap == 3)
        #expect(SettingsWidthClass.compact.homeColumnCap == 2)
        #expect(SettingsWidthClass.tight.homeColumnCap == 2)
        // Two 240 pt cards and their gap fit inside the
        // minimum window's grid; three do not.
        let usable = SettingsWidthClass.minimum - 2 * 16
        #expect(2 * 240 + 16 <= usable)
        #expect(3 * 240 + 2 * 16 > usable)
    }

    /// The shell spends the minimum through the same constant
    /// the bands are cut from — a second literal 720 in the
    /// frame is how the window comes to resize below its own
    /// narrowest band.
    @Test("the shell's minimum is the bands' minimum")
    func shellSpendsTheMinimum() throws {
        let source = try squashed(
            "Sources/KiwiDesk/Settings/SettingsView.swift"
        )
        #expect(
            source.contains(
                ".frame(minWidth:SettingsWidthClass.minimum,"
                    + "minHeight:540)"
            )
        )
    }

    private func squashed(_ path: String) throws -> String {
        let url = Self.root.appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }
}
