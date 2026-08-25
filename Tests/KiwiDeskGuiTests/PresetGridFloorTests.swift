import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// A declared grid `minimum:` is a width the card can actually be
/// laid out at (#862). Since #859 a preset card's action row is
/// two `.large` buttons, and the pair's width is eleven catalogs'
/// business — so the floor cannot be checked by reading the view.
///
/// **Why this is not the vacuous shape.** The obvious test defines
/// the pair's width as a constant and asserts the floor clears it,
/// which recomputes both sides from constants this branch wrote
/// and models nothing they do not already say — 4c shipped that
/// mistake twice, the second time as a "fix" for the first. Here
/// the two sides come from different places and neither is the
/// test's invention:
///
/// - the FLOOR and the paddings are read off `PresetCard`, the
///   view that draws them, never restated here;
/// - the PAIR is measured from the shipped catalogs through
///   AppKit's own `sizeToFit`, so a translation that grows reds
///   this without anyone editing a test.
///
/// That is also why it is worth having at all: the failure it
/// watches for arrives in a translation round, in a language the
/// reviewer does not read, months after the constant was set.
///
/// **What it cannot see**, stated so a green run is not read as
/// more. `.flexible` honours the column COUNT and compresses PAST
/// its minimum rather than reflowing, so this proves the declared
/// floor is honest, not that a card is never drawn narrower than
/// it. Whether the content column can push three columns below
/// the floor is a device measurement (#862 asks for it), and it
/// is not reachable at today's `presetColumnCap` — three columns
/// only occur at `.wide`. Nor does it measure the card's other
/// content: the title, the summary and the picture flex, and only
/// the button row cannot.
///
/// **Main-actor load is deliberately minimal here.** Only the
/// AppKit measurement is `@MainActor`, and it memoizes by title;
/// the catalog reads and the two source scans run off it. That is
/// not tidiness — `tests.md` ▸ Async tests carries the
/// measurement and the obligation: heavy synchronous `@MainActor`
/// work backs the main actor up past 30 s in a full run, and the
/// first cut of this suite was one of them. It went `@MainActor`
/// wholesale, and CI timed a suite out against its 120 s guard
/// while the whole thing passes in 1.3 s locally (2026-08-17).
/// The main actor is a shared budget, and a new suite spends it.
///
/// **And it cannot see ADDITIVE drift**, which `guard-prover`
/// demonstrated: keep `.padding(Self.padding)` and add a second
/// `.padding(6)` under it, put 6 pt on one button, and the card
/// really draws 244 pt of interior against a row this floor sizes
/// for 256 — #862's own defect at a smaller magnitude, with every
/// test here green. The needles below prove the constants are
/// USED, never that they are the whole inset. Closing that would
/// mean measuring a rendered card rather than reading its source,
/// which is a different kind of test than this one.
@Suite("Preset grid floor (#862)")
struct PresetGridFloorTests {
    /// The two keys the action row draws, in the order it draws
    /// them. Not a register of anything — the values come from
    /// the catalogs.
    private static let actionKeys = ["presets.layouts", "presets.apply"]

    private static func catalogs() throws -> [String: [String: String]] {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Locales")
        var out: [String: [String: String]] = [:]
        for url in try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) where url.pathExtension == "json" {
            let name = url.deletingPathExtension().lastPathComponent
            guard !name.hasPrefix("missing_") else { continue }
            out[name] = try JSONDecoder().decode(
                [String: String].self,
                from: Data(contentsOf: url)
            )
        }
        return out
    }

    /// AppKit's own intrinsic width at the control size the
    /// card draws its buttons at.
    ///
    /// The card draws SwiftUI `.bordered` through
    /// `settingsActionButton()`; this measures an `NSButton`
    /// with the matching bezel. The pairing is UNGUARDED — a
    /// change to `.controlSize` in `PresetCard` silently
    /// re-rates every width the floor rests on, and
    /// `cardDrawsItsDeclaredMetrics` needles the two spacing
    /// constants, not the size. Stated rather than asserted
    /// because pinning it would mean rendering the real card.
    /// Memoized, and the memo is not a micro-optimisation.
    /// Heavy synchronous `@MainActor` suites back the main actor
    /// up past 30 s in a full run (`tests.md` ▸ Async tests), and
    /// this suite is one. Distinct titles are far fewer than catalogs
    /// times keys, so measuring each once is most of the load
    /// gone for free.
    @MainActor private static var widths: [String: CGFloat] = [:]

    @MainActor
    private static func buttonWidth(_ title: String) -> CGFloat {
        if let cached = widths[title] { return cached }
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.sizeToFit()
        let width = button.frame.width
        widths[title] = width
        return width
    }

    /// The scan found catalogs. An empty corpus would make every
    /// assertion below pass for having measured nothing —
    /// `rule-authoring.md`'s "assert its input is non-empty
    /// before asserting anything about it".
    @Test("the catalogs are readable, and there are enough")
    func corpusIsPresent() throws {
        let all = try Self.catalogs()
        #expect(
            all.count >= 11,
            """
            found \(all.count) catalog(s) — the corpus read is \
            broken, not the tree.
            """
        )
        #expect(all["en"] != nil, "en.json did not decode")
        for key in Self.actionKeys {
            #expect(
                all["en"]?[key]?.isEmpty == false,
                "\(key) is not in en.json — the row moved"
            )
        }
    }

    /// The floor holds the widest shipped button pair.
    @MainActor
    @Test("every catalog's action row fits the declared floor")
    func actionRowFitsTheFloor() throws {
        let all = try Self.catalogs()
        let english = all["en"] ?? [:]
        let interior =
            PresetCard.minimumWidth - 2 * PresetCard.padding

        var widest: (locale: String, width: CGFloat) = ("", 0)
        var measuredOwn = 0
        for (locale, catalog) in all.sorted(by: { $0.key < $1.key }) {
            // A locale that has not translated the key falls back
            // to English at runtime, so measure what would DRAW.
            let titles = Self.actionKeys.map {
                catalog[$0] ?? english[$0] ?? ""
            }
            if locale != "en",
                Self.actionKeys.allSatisfy({ catalog[$0] != nil })
            {
                measuredOwn += 1
            }
            let pair =
                titles.map(Self.buttonWidth).reduce(0, +)
                + PresetCard.buttonRowSpacing
            if pair > widest.width { widest = (locale, pair) }
            #expect(
                pair <= interior,
                """
                \(locale): the action row measures \
                \(String(format: "%.1f", pair)) pt against \
                \(String(format: "%.1f", interior)) pt of card \
                interior at PresetCard.minimumWidth \
                (\(String(format: "%.0f", PresetCard.minimumWidth)) \
                pt less \(String(format: "%.0f", PresetCard.padding)) \
                pt of padding a side). Either shorten that \
                locale's \(Self.actionKeys.joined(separator: " / ")) \
                — localization.md rules an ACTION label to the \
                shortest true verb — or raise the floor. Do not \
                narrow the padding: it is the card's, not this \
                row's.
                """
            )
        }
        #expect(
            widest.width > 0,
            "no catalog produced a measurable pair"
        )
        // Proof that the TRANSLATIONS were measured, not English
        // eleven times.
        //
        // The first attempt at this was `widest.locale != "en"`,
        // and `guard-prover` proved it INERT: the comparison is
        // strictly greater and the loop walks sorted order, so
        // when every locale falls back to the same English string
        // the winner is `de`, never `en`. It could not fire for
        // the mutation it was written to catch, and it would have
        // misfired if it could — an English relabel that
        // legitimately became the longest string would have been
        // reported as a lost translation.
        //
        // So count what the collapse actually destroys: how many
        // catalogs answered BOTH keys out of their own map. A
        // fallback pointed the wrong way drops this to zero; one
        // missing translation drops it by one, which the old
        // shape could not see at all.
        #expect(
            measuredOwn == all.count - 1,
            """
            \(measuredOwn) of \(all.count - 1) translated \
            catalogs supplied both \
            \(Self.actionKeys.joined(separator: " / ")) from \
            their own map. Either a translation is missing from \
            the corpus, or the measuring path is falling back to \
            English and this guard is measuring one string \
            \(all.count) times.
            """
        )
    }

    /// The card DRAWS the constants it declares.
    ///
    /// Found by `guard-prover` rather than reasoned about: with
    /// `padding` and `buttonRowSpacing` left at 12 and 8 while
    /// `body` drew `.padding(24)` and `HStack(spacing: 20)`, the
    /// card needed 265 pt of row inside 232 pt of interior — #862
    /// live — and every assertion above passed. They read the
    /// DECLARATIONS, so a `body` that ignores them makes the
    /// floor honest about a card that does not exist.
    ///
    /// A needle, at the same altitude as the grid's, because the
    /// alternative is rendering the card and measuring it, which
    /// needs a hosted view for two numbers that are right there
    /// in the source.
    @Test("the card draws the constants the floor is built on")
    func cardDrawsItsDeclaredMetrics() throws {
        let source = try String(
            contentsOf: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources")
                .appendingPathComponent("KiwiDesk")
                .appendingPathComponent("Settings")
                .appendingPathComponent("Components")
                .appendingPathComponent("Profiles")
                .appendingPathComponent("PresetCard.swift"),
            encoding: .utf8
        )
        let stripped = SourceScan.stripComments(source)
        for needle in [
            ".padding(Self.padding)",
            "HStack(spacing: Self.buttonRowSpacing)",
        ] {
            #expect(
                stripped.contains(needle),
                """
                PresetCard's body no longer contains \
                `\(needle)`. The floor is computed from those \
                constants, so a body that lays out some other \
                way describes a card that is not on screen. \
                NOTE: this needle matches one SPELLING — if you \
                rewrote it to still read the constant (a local \
                alias, an EdgeInsets built from it) the code may \
                be correct and this message wrong; widen the \
                needle rather than silencing it.
                """
            )
        }
    }

    /// The grid asks the card for its floor rather than declaring
    /// a second, smaller opinion of its own — which is the defect
    /// #862 reported. Keyed on the call site, because the
    /// arithmetic above passes just as well against a literal the
    /// grid never reads.
    @Test("the grid's minimum is the card's own floor")
    func gridReadsTheCardsFloor() throws {
        let source = try String(
            contentsOf: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources")
                .appendingPathComponent("KiwiDesk")
                .appendingPathComponent("Settings")
                .appendingPathComponent("Sections")
                .appendingPathComponent("PresetsSection.swift"),
            encoding: .utf8
        )
        let stripped = SourceScan.stripComments(source)
        #expect(
            stripped.contains(
                ".flexible(minimum: PresetCard.minimumWidth)"
            ),
            """
            PresetsSection's grid no longer takes its minimum \
            from PresetCard.minimumWidth — a second opinion about \
            the floor is exactly what #862 reported.
            """
        )
    }
}
