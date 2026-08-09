import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a display's readout says (#678 Phase 3, turn 13b).
///
/// Written after guard-prover found the sentence had NO
/// behavioural test at all: its zero arm could be made
/// unreachable and the follows-main term could be dropped from
/// `held(on:isMain:)` with the whole 2819-test suite green — and
/// that term is itself the fix for a defect this turn shipped and
/// caught in review ("0 spaces here" on every card of a desk
/// where every space follows main). A source scan held the keys;
/// nothing held the arithmetic that chooses between them.
///
/// `@MainActor` because `MonitorReadout` is: `L()` routes through
/// the main-actor locale catalog.
@MainActor
@Suite("Monitor readout sentence")
struct MonitorReadoutTests {
    /// Every assertion below compares `L()` output to English,
    /// so each test pins the shared manager as its FIRST line —
    /// "System default" resolves the HOST's language, and on a
    /// German machine every sentence here came back from
    /// `de.json` (caught 2026-08-09; `ShortcutsSelfRowTests` is
    /// the standing idiom). Inside the body, not `init`:
    /// suites interleave on the main actor at the init→body
    /// hop, and `LocalizationManagerTests`' own select() calls
    /// landed in that window — a synchronous body has no
    /// suspension point for them to land in.
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func display(
        _ id: UInt32,
        _ name: String = "Desk"
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)
        )
    }

    /// A display holding nothing says so, rather than reaching the
    /// plural arm and reading "0 spaces here".
    @Test("zero takes its own sentence")
    func zeroHasItsOwnPhrase() {
        pinEnglish()
        let empty = MonitorReadout.sentence(held: 0, showing: nil)
        #expect(empty == "No spaces here")
        #expect(!empty.contains("0"))
    }

    /// …and keeps it even when a space is up on that screen: our
    /// own accounting says the display holds nothing, so a
    /// sentence claiming both would contradict itself.
    @Test("zero keeps its sentence when something is showing")
    func zeroIgnoresShowing() {
        pinEnglish()
        let sentence = MonitorReadout.sentence(
            held: 0,
            showing: SpaceID("code")
        )
        #expect(sentence == "No spaces here")
    }

    /// One and many are separate PHRASES, not a number glued to an
    /// English plural — the reason the count never appears as
    /// "%1$d space(s)".
    @Test("one and many are different sentences")
    func countPhrasesDiffer() {
        pinEnglish()
        let one = MonitorReadout.sentence(held: 1, showing: nil)
        let many = MonitorReadout.sentence(held: 4, showing: nil)
        #expect(one == "1 space here")
        #expect(many == "4 spaces here")
        #expect(one != many)
    }

    /// The showing clause NAMES the space rather than dropping the
    /// id in bare: ids are commonly numeric, and "3 spaces here ·
    /// 2 is showing" is two numerals with no noun on either.
    @Test("the showing clause names its space")
    func showingNamesTheSpace() {
        pinEnglish()
        let sentence = MonitorReadout.sentence(
            held: 3,
            showing: SpaceID("code")
        )
        #expect(sentence.contains("3 spaces here"))
        #expect(sentence.contains("space code is showing"))
        // One sentence, not a phrase composed into a frame: the
        // count arm and the showing arm are one key each.
        #expect(
            sentence == "3 spaces here · space code is showing"
        )
    }

    @Test("one-with-showing has its own sentence too")
    func singularWithShowing() {
        pinEnglish()
        #expect(
            MonitorReadout.sentence(
                held: 1,
                showing: SpaceID("web")
            ) == "1 space here · space web is showing"
        )
    }

    // MARK: - What the count is counted from

    /// The main display HOLDS the spaces that follow main — they
    /// are on that screen right now, which is what the readout
    /// claims to answer.
    ///
    /// This is the term guard-prover could delete with the whole
    /// suite green, and deleting it returns the exact defect this
    /// turn fixed: a desk where every space follows main reads
    /// "No spaces here" on the display they are all sitting on.
    @Test("the main display counts the tray's spaces")
    func mainCountsTheTray() {
        pinEnglish()
        let desk = display(1)
        let rows = MonitorsFamilyRows(
            spaces: [
                SpaceID("code"), SpaceID("web"), SpaceID("chat"),
            ],
            mainSpaces: [SpaceID("code"), SpaceID("web")],
            resolutions: [
                SpaceID("chat"): .auto(desk.fingerprint),
                SpaceID("code"): .main,
                SpaceID("web"): .main,
            ],
            pins: [:],
            displays: [desk]
        )
        // One carded chip, two in the tray.
        #expect(rows.chips(on: desk.fingerprint).count == 1)
        #expect(rows.trayChips.count == 2)
        #expect(rows.held(on: desk, isMain: true) == 3)
        // A display that is NOT main holds only its own.
        #expect(rows.held(on: desk, isMain: false) == 1)
    }

    /// The everything-follows-main desk, end to end: without the
    /// tray term this renders "No spaces here" while three spaces
    /// sit on that screen.
    @Test("a follows-main desk does not read as empty")
    func followsMainDeskIsNotEmpty() {
        pinEnglish()
        let desk = display(1)
        let spaces = [
            SpaceID("code"), SpaceID("web"), SpaceID("chat"),
        ]
        let rows = MonitorsFamilyRows(
            spaces: spaces,
            mainSpaces: Set(spaces),
            resolutions: Dictionary(
                uniqueKeysWithValues: spaces.map { ($0, .main) }
            ),
            pins: [:],
            displays: [desk]
        )
        let sentence = MonitorReadout.sentence(
            held: rows.held(on: desk, isMain: true),
            showing: SpaceID("code")
        )
        #expect(sentence.hasPrefix("3 spaces here"))
        #expect(!sentence.contains("No spaces here"))
    }
}
