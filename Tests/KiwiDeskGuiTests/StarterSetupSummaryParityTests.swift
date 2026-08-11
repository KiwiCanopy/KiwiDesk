import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Starter preset's summary must not name the layouts it lays
/// down — the guard that replaces a parity check, by removing the
/// second copy rather than comparing it.
///
/// **Why there was ever a pair.** The ladder's summary named its
/// rungs one by one, so the English copy and the mode list were
/// two hand-written copies of one thing, and they drifted silently
/// and in the direction nothing could see. `016cc50a` — a commit
/// about the activation policy — flipped rung 2 from `.stack` to
/// `.bsp` while every piece of prose kept saying "Stack": the
/// Settings summary, all eleven catalogs, and the user guide. No
/// gate could catch it. `extract-keys --check` compares keys
/// against call sites and the English literal was untouched, so it
/// stayed green; the catalogs were not stale, they were faithfully
/// translating a sentence that had become false.
///
/// **Why the pair is gone.** Since #678 Phase 4 pass 11 the setup
/// derives its modes from the shapes of the connected screens, so
/// a sentence naming them would be a different sentence on every
/// Mac and could not be authored at all. The summary states the
/// rule instead. That makes the old drift impossible rather than
/// merely watched — but only for as long as nobody adds a mode
/// name back, which is what this suite now watches.
///
/// The mode a preset assigns is not a detail a user can shrug off:
/// picking Starter is how someone learns what the layouts *are*,
/// so a summary that names the wrong one teaches the wrong name
/// for the layout they are looking at. A summary that names none
/// cannot.
@Suite("Starter summary independence", .serialized)
@MainActor
struct StarterSetupSummaryParityTests {
    /// Four setups whose derived modes differ, so a summary that
    /// leaked ANY of them is caught whichever shape leaked it.
    private var setups: [[CGSize]] {
        [
            [CGSize(width: 1728, height: 1117)],
            [CGSize(width: 2560, height: 1440)],
            [CGSize(width: 3440, height: 1440)],
            [CGSize(width: 1440, height: 2560)],
        ]
    }

    @Test("The summary names no layout mode")
    func summaryNamesNoMode() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }

        let names = LayoutMode.allCases.map(\.displayName)
        #expect(!names.isEmpty)
        for sizes in setups {
            let summary = StarterSetup.standardLayout(sizes: sizes)
                .displaySummary
            #expect(!summary.isEmpty)
            for name in names {
                #expect(
                    !summary.contains(name),
                    """
                    The Starter summary names "\(name)", which is \
                    a layout this setup may not lay down — the \
                    modes come from the screens. Summary: \
                    "\(summary)"
                    """
                )
            }
        }
    }

    /// Vacuity: the sweep above proves nothing if the setups all
    /// derive the same modes, since then "names no mode" would be
    /// one claim rather than four.
    @Test("The four setups really do derive different modes")
    func setupsDiffer() {
        let derived = setups.map { sizes in
            StarterSetup.spaceModes(sizes: sizes)
        }
        #expect(Set(derived.map { String(describing: $0) }).count > 1)
    }

    /// The one sentence is the same sentence everywhere, which is
    /// what "states the rule" means — a `where screenCount` arm
    /// re-introducing a per-count variant reds here.
    @Test("One summary, whatever the screens")
    func summaryIsOneSentence() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let summaries = setups.map {
            StarterSetup.standardLayout(sizes: $0).displaySummary
        }
        #expect(Set(summaries).count == 1)
    }
}
