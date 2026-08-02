import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// The sidebar's width budget, enforced instead of remeasured by
/// hand. `SettingsSidebar` fixes the column, and the rule that
/// follows is that a destination label past what the column
/// leaves for text gets a SHORTER LABEL, never a wider sidebar.
/// Nothing checked it, so four `sidebar.layout` translations
/// drifted past the budget after #95 shortened fifteen others —
/// `es` reached 214 pt, nearly double — and each one truncated on
/// screen in a language no reviewer here reads.
///
/// Like `LocalizationRegistryTests`, this suite walks the shipped
/// catalogs on purpose. The thing under test *is* the corpus —
/// "every label we ship fits the column" has no meaning against
/// strings the test invents — and it cannot pass for the wrong
/// reason: a too-long translation reds it until the label is
/// shortened, which is the intended trigger.
///
/// Where the net stops, so the next author does not read a green
/// run as more than it is:
/// - `SettingsMetrics.sidebarRowChrome` is a measured estimate of
///   AppKit's own row insets. The budget tracks the column and
///   the tile, both proven by mutation, but a `.sidebar` list
///   style that changes its insets moves the real text room
///   without moving the estimate, and this stays green.
/// - It measures `systemFont(ofSize: 13)`; the row renders
///   whatever the `.sidebar` list style resolves. Adding a
///   `.font(…)` to that row diverges the two silently —
///   `measurementIsLive` catches a dead metric, not a wrong one.
/// - The metric is the HOST's, and the tightest untouched label
///   clears `sidebarLabelColumn` by about 2%, so a runner whose
///   SF metrics differ by more than that reds a label no change
///   touched. Re-derive the budget before shortening a label
///   that only fails on one machine.
/// - Only the destination titles. The section headers, the app
///   name, the empty-search line and `SidebarSearchRow`'s
///   primary + breadcrumb — the longest text in the column —
///   share it and are unmeasured. The search row's truncation is
///   deliberate; the destination rows' is not.
@Suite("Sidebar label width budget")
struct SidebarLabelWidthTests {
    /// Past this a label truncates. Read from the metric rather
    /// than restated, so narrowing the column or widening the
    /// tile tightens the budget here in the same move instead of
    /// leaving this guard enforcing a tolerance the column no
    /// longer has.
    private static var budget: CGFloat {
        SettingsMetrics.sidebarLabelColumn
    }

    /// The point size a sidebar row's `Label` title renders at.
    /// The `NSFont` itself is built per call — it is not
    /// `Sendable`, so it cannot be a `static let` here.
    private static let fontSize: CGFloat = 13

    private static func width(_ text: String) -> CGFloat {
        (text as NSString)
            .size(withAttributes: [
                .font: NSFont.systemFont(ofSize: fontSize)
            ])
            .width
    }

    private static let repoRoot = SourceScan.repoRoot(
        from: #filePath
    )

    private static var localesDirectory: URL {
        repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Locales")
    }

    /// The destinations' `L(key, english)` pairs, scanned from
    /// the source rather than re-listed here — a hand-listed key
    /// set is one more place to forget a new destination, and
    /// `titleKeysCoverEveryDestination` pins the count so a
    /// missed one reds rather than going unread. The scan is
    /// shared with `SidebarCrossReferenceTests`, which matches
    /// breadcrumbs against the same set.
    private static func titles() throws
        -> [SourceScan.SidebarTitle]
    {
        try SourceScan.sidebarTitles(root: repoRoot)
    }

    /// Every shipped `<locale>.json`, `en.json` excluded — its
    /// values are the generated manifest of the same English
    /// that lives at the call sites.
    private static func catalogs() throws
        -> [String: [String: String]]
    {
        let files = try FileManager.default.contentsOfDirectory(
            at: localesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
        .filter { !$0.lastPathComponent.hasPrefix("missing_") }
        .filter { $0.lastPathComponent != "en.json" }
        var out: [String: [String: String]] = [:]
        for file in files {
            out[
                String(
                    file.lastPathComponent.dropLast(
                        ".json".count
                    )
                )
            ] = try JSONDecoder().decode(
                [String: String].self,
                from: Data(contentsOf: file)
            )
        }
        return out
    }

    /// Non-vacuity AND attribution for the measurement itself. A
    /// font that failed to resolve would report every label at
    /// 0 pt and pass the budget silently — but a band wide
    /// enough to only catch that is the wrong shape here,
    /// because the tightest shipped label clears the budget by
    /// about 2%. A looser canary would stay green while host
    /// metric drift red the budget test instead, and the message
    /// there says "shorten the label" about a string no commit
    /// touched (#523 is what a host-inherited assertion costs).
    ///
    /// So the band is TIGHTER than the labels' own margin: 1%
    /// around this datum, measured 2026-08-03 on macOS 26. Host
    /// drift then reds here first, and reds as what it is.
    @Test func measurementIsLive() {
        let datum: CGFloat = 94.4
        let reference = Self.width("Layout Defaults")
        #expect(
            abs(reference - datum) < datum / 100,
            """
            "Layout Defaults" measures \(reference) pt, not the \
            \(datum) pt this host was calibrated at — the text \
            metric moved, so re-derive the budget before \
            treating any width failure as a label defect
            """
        )
    }

    @Test func titleKeysCoverEveryDestination() throws {
        let titles = try Self.titles()
        #expect(
            titles.count == SettingsDestination.allCases.count
        )
        #expect(Set(titles.map(\.key)).count == titles.count)
    }

    /// English ships too, and no catalog carries it — it lives at
    /// the `L()` call site, so `en.json` is excluded above and a
    /// too-long ENGLISH label would clear every other assertion
    /// here.
    @Test func englishLabelsFitTheColumn() throws {
        let titles = try Self.titles()
        #expect(!titles.isEmpty)
        for title in titles {
            #expect(
                Self.width(title.english) <= Self.budget,
                """
                en \(title.key) "\(title.english)" measures \
                \(Self.width(title.english)) pt, past the \
                \(Self.budget) pt sidebar budget
                """
            )
        }
    }

    @Test func everyShippedLabelFitsTheColumn() throws {
        let keys = try Self.titles().map(\.key)
        let catalogs = try Self.catalogs()
        // Guard the fixture: a misplaced locale directory must
        // red, not pass having read nothing.
        #expect(catalogs.count > 1)
        var measured = 0
        for (locale, catalog) in catalogs {
            for key in keys {
                guard let label = catalog[key] else { continue }
                measured += 1
                let width = Self.width(label)
                #expect(
                    width <= Self.budget,
                    """
                    \(locale) \(key) "\(label)" measures \
                    \(width) pt, past the \(Self.budget) pt \
                    sidebar budget — shorten the label, never \
                    widen the column
                    """
                )
            }
        }
        // Derived, not a hand-picked floor: every shipped
        // catalog carries every destination key today, so the
        // coverage is exactly the product. A locale MAY omit a
        // key — per-key fallback is legal — but then its label
        // is the English one, and this is where you find out
        // that `englishLabelsFitTheColumn` is the only net left
        // for it.
        //
        // So this reds MID-WORKFLOW, by design: between
        // `scripts/drop-key --locale` and `scripts/merge-keys`
        // the dropped locale is short a key, and a destination
        // added ahead of its translations reds it too. Neither
        // is a width defect — finish the round-trip.
        #expect(measured == keys.count * catalogs.count)
    }
}
