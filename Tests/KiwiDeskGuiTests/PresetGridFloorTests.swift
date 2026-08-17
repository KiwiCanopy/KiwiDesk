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
@MainActor
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

    /// AppKit's own intrinsic width for the button the card
    /// draws, at the bezel and control size it draws it at.
    private static func buttonWidth(_ title: String) -> CGFloat {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.sizeToFit()
        return button.frame.width
    }

    /// The scan found catalogs. An empty corpus would make every
    /// assertion below pass for having measured nothing —
    /// `rule-authoring.md`'s "assert its input is non-empty
    /// before asserting anything about it".
    @Test("the catalogs are readable, and there are eleven")
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
    @Test("every catalog's action row fits the declared floor")
    func actionRowFitsTheFloor() throws {
        let all = try Self.catalogs()
        let english = all["en"] ?? [:]
        let interior =
            PresetCard.minimumWidth - 2 * PresetCard.padding

        var widest: (locale: String, width: CGFloat) = ("", 0)
        for (locale, catalog) in all.sorted(by: { $0.key < $1.key }) {
            // A locale that has not translated the key falls back
            // to English at runtime, so measure what would DRAW.
            let titles = Self.actionKeys.map {
                catalog[$0] ?? english[$0] ?? ""
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
