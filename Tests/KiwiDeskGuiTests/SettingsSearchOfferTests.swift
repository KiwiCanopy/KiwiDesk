import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the search panel shows BEFORE a query (#1030): one row,
/// the Guide, and never through `results("")` — that contract
/// stays `SettingsSearchTests ▸ emptyQuery`'s. Split from that
/// suite: matching is its subject, the offer is a second
/// producer with rules of its own.
@Suite("Settings search offer", .serialized)
@MainActor
struct SettingsSearchOfferTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// Exactly one row, keyed on the catalog's Guide link, so a
    /// pick lands on General ▸ About's link rather than in a
    /// browser — a row shaped like a result promises navigation
    /// inside the window. A second row is the curated list the
    /// issue refused: a census that can rot.
    @Test("the offer is the Guide, once")
    func offerIsTheGuide() {
        pinEnglish()
        defer { reset() }
        let offer = SettingsSearch.offer(
            context: SettingsSearchContext()
        )
        #expect(offer.count == 1)
        guard case .setting(let row) = offer.first else {
            Issue.record("the offer is not a settings row")
            return
        }
        #expect(row.key == nil)
        #expect(row.destination == .general)
        #expect(
            row.anchor.anchor
                == SettingsCatalog.general.guideLink.id
        )
        #expect(row.label == "Guide")
        // The same row a typed query finds, so the two never
        // drift in label, anchor or breadcrumb.
        let typed = SettingsSearch.results(
            query: "Guide",
            context: SettingsSearchContext()
        )
        .settings
        #expect(typed.contains(offer[0]))
    }

    /// Nothing drawn before a query passes is offered outside
    /// the ONE offer predicate (gui.md ▸ Home is the only
    /// navigator), and none of it may reconfigure the window:
    /// over every context axis the shell knows, each offered
    /// row is one `HomeCardOrder.isOffered` admits, and so one
    /// `switchesMode` refuses to tag.
    @Test("the offer never leaves the offer predicate")
    func offerStaysInsideThePredicate() {
        pinEnglish()
        defer { reset() }
        var seen = 0
        for mode in [SettingsMode.simple, .powerUser] {
            for displays in [1, 2] {
                for editing in [false, true] {
                    let context = SettingsSearchContext(
                        editingStoredProfile: editing,
                        mode: mode,
                        displayCount: displays
                    )
                    for result in SettingsSearch.offer(
                        context: context
                    ) {
                        seen += 1
                        #expect(
                            HomeCardOrder.isOffered(
                                result.destination,
                                mode: mode,
                                displayCount: displays,
                                editingStoredProfile: editing
                            )
                        )
                        #expect(
                            !SettingsSearch.switchesMode(
                                result,
                                context: context
                            )
                        )
                    }
                }
            }
        }
        // Non-vacuity: the loop offered something somewhere.
        #expect(seen > 0)
    }

    /// The #18 axis, stated outright: General is withheld while
    /// a stored profile is edited, and with it the offer — an
    /// empty panel is right there, not a row that cannot land.
    @Test("editing a stored profile withholds the offer")
    func storedProfileWithholdsTheOffer() {
        pinEnglish()
        defer { reset() }
        var context = SettingsSearchContext()
        context.editingStoredProfile = true
        #expect(SettingsSearch.offer(context: context).isEmpty)
        context.editingStoredProfile = false
        #expect(!SettingsSearch.offer(context: context).isEmpty)
    }

    /// Simple mode offers it too: General is a Simple area, so
    /// the row carries no mode tag and the panel is not a
    /// Power-User-only affordance.
    @Test("Simple mode offers the Guide untagged")
    func simpleModeOffersIt() {
        pinEnglish()
        defer { reset() }
        var context = SettingsSearchContext()
        context.mode = .simple
        let offer = SettingsSearch.offer(context: context)
        #expect(offer.count == 1)
        #expect(
            offer.allSatisfy {
                !SettingsSearch.switchesMode($0, context: context)
            }
        )
    }
}
