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

    /// The three numbers, restated on purpose — the one place
    /// in this suite that does. They are a RULING (digest turn
    /// 17a), not a value derived from anything the tree owns,
    /// so there is nothing to derive them from and this is the
    /// only record that they are what was ruled. What it buys
    /// is that a retune has to edit a test that says so, rather
    /// than passing as an implementation detail; every other
    /// assertion here derives from the enum instead.
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

    /// Each step gets a band of its own — the ladder is three
    /// separate widths, not two steps landing together.
    ///
    /// `theOrderHolds` cannot see this and that is not a gap in
    /// it: implications forbid chrome collapsing BEFORE rows
    /// reflow, and say nothing about the two happening at the
    /// same width. Collapsing the header at 900 satisfies every
    /// one of them (guard-prover, 2026-08-11), and it would
    /// silently retire the compact band — an arrangement the
    /// digest drew a frame for.
    @Test("each step has a band of its own")
    func stepsDoNotMerge() {
        let bands = supportedWidths.map(SettingsWidthClass.of)
        // Shed the preview, and nothing else yet.
        #expect(
            bands.contains {
                !$0.docksPanel && !$0.stacksRows
            }
        )
        // Shed the row axis, and still keep the chrome.
        #expect(
            bands.contains {
                $0.stacksRows && !$0.collapsesChrome
            }
        )
        // And shed the chrome.
        #expect(bands.contains { $0.collapsesChrome })
        // The fullest form is reachable too, or the ladder has
        // no top.
        #expect(bands.contains { $0.docksPanel })
    }

    /// A window with no saved frame opens in the FULLEST band.
    /// The old default (860) predates the bands and now names
    /// the compact one, so it would have met every new user
    /// with two-line rows and a docked save bar — the most
    /// degraded arrangement the app has, for someone who asked
    /// for nothing (code review + architecture review,
    /// 2026-08-11).
    @Test("a first launch opens in the fullest band")
    @MainActor
    func firstLaunchOpensWide() {
        let width = SettingsWindowController.firstRunWidth
        #expect(SettingsWidthClass.of(width: width) == .wide)
        #expect(width >= SettingsWidthClass.minimum)
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
        // minimum window's grid; three do not. The pane inset
        // is read rather than restated — it was a literal 16
        // here for a day, standing for a DIFFERENT 16 than the
        // grid spacing `HomeCardChromeTests` pins
        // (guard-prover, 2026-08-11). Stated residue: 240 and
        // the grid's own 16 are still `HomeScreen`'s private
        // literals, covered by that suite rather than owned
        // here.
        let usable =
            SettingsWidthClass.minimum
            - 2 * SettingsMetrics.paneInset
        #expect(2 * 240 + 16 <= usable)
        #expect(3 * 240 + 2 * 16 > usable)
    }

    /// The shell spends BOTH floors through the constants the
    /// bands are cut from — a second literal in the frame is how
    /// the window comes to resize below its own narrowest band.
    ///
    /// The HEIGHT half was a literal `540`, and this needle pinned
    /// it as one, until #859 wanted the same number to bound a
    /// sheet and found nothing to derive from: its own bounds went
    /// in as literals with a comment claiming a relation to this
    /// frame that did not hold (code review, 2026-08-17). Naming
    /// the pair is what makes that relation assertable, so the
    /// needle now demands the constant rather than the number.
    @Test("the shell's minimums are the bands' minimums")
    func shellSpendsTheMinimum() throws {
        let source = try squashed(
            "Sources/KiwiDesk/Settings/SettingsView.swift"
        )
        #expect(
            source.contains(
                ".frame(minWidth:SettingsWidthClass.minimum,"
                    + "minHeight:SettingsWidthClass.minimumHeight)"
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
