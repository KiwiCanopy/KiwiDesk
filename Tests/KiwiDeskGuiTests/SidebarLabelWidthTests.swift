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
/// - `SettingsSidebar.labelChrome` is hand-measured. The budget
///   tracks the *column*, proven by mutation, but widening
///   `SidebarTile` or the row insets shrinks the real text room
///   without moving the chrome, and this stays green.
/// - It measures `systemFont(ofSize: 13)`; the row renders
///   whatever the `.sidebar` list style resolves. Adding a
///   `.font(…)` to that row diverges the two silently —
///   `measurementIsLive` catches a dead metric, not a wrong one.
/// - Only the destination titles. The section headers, the app
///   name and the empty-search line share the column and are
///   unmeasured.
@Suite("Sidebar label width budget")
struct SidebarLabelWidthTests {
    /// Past this a label truncates. Derived from the column
    /// rather than restated: narrowing `SettingsSidebar` tightens
    /// the budget here in the same move, instead of leaving this
    /// guard enforcing a tolerance the column no longer has.
    private static var budget: CGFloat {
        SettingsSidebar.columnWidth - SettingsSidebar.labelChrome
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

    /// The `L(key, english)` pairs `SettingsDestination.title`
    /// names, read from the source rather than re-listed here —
    /// a hand-listed key set is one more place to forget a new
    /// destination, and `titleKeysCoverEveryDestination` pins
    /// the count so a missed one reds rather than going unread.
    ///
    /// Comments are stripped first: a doc-comment example naming
    /// an `L("sidebar.…")` would otherwise inflate the count and
    /// mask a title that really is missing one.
    private static func titles() throws -> [(
        key: String, english: String
    )] {
        let source = SourceScan.stripComments(
            try String(
                contentsOf:
                    repoRoot
                    .appendingPathComponent("Sources")
                    .appendingPathComponent("KiwiDesk")
                    .appendingPathComponent("Settings")
                    .appendingPathComponent(
                        "SettingsDestination.swift"
                    ),
                encoding: .utf8
            )
        )
        let pattern = #"L\("(sidebar\.[a-z_]+)", "([^"]+)"\)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: range)
            .compactMap { match in
                guard
                    let key = Range(
                        match.range(at: 1),
                        in: source
                    ).map({ String(source[$0]) }),
                    let english = Range(
                        match.range(at: 2),
                        in: source
                    ).map({ String(source[$0]) })
                else { return nil }
                return (key, english)
            }
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

    /// Non-vacuity for the measurement itself: a font that failed
    /// to resolve, or a metric that changed under us, would
    /// report every label at 0 pt and pass the budget silently.
    /// A sane band, not a pinned datum — the exact figure lives
    /// in `SettingsSidebar.swift` and is not restated here.
    @Test func measurementIsLive() {
        let reference = Self.width("Layout Defaults")
        #expect(reference > 80)
        #expect(reference < 110)
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
        #expect(measured > 50)
    }
}
