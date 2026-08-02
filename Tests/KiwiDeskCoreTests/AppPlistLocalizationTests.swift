import Foundation
import Testing

@testable import KiwiDeskCore

/// The packaged `.app` must tell macOS which languages it
/// speaks, and must derive that list from the shipped catalogs
/// rather than carry a typed copy of them.
///
/// The failure this guards is silent in a way the language
/// picker cannot show: with no `CFBundleLocalizations`, macOS
/// resolves the process locale to `CFBundleDevelopmentRegion`,
/// so "System default" answers English on a German Mac and every
/// catalog in `Resources/Locales` becomes unreachable except by
/// picking it by hand. Nothing crashes and nothing logs — the app
/// is simply monolingual for anyone who never opens Settings
/// (#659).
///
/// **What this suite can and cannot see.** It reads
/// `build-app.sh` as *text*, so it proves the script still says
/// the right things; it does not execute the script and does not
/// parse a built plist. Two consequences, both deliberate:
///
/// - It follows `LOCALE_KEYS` from its initializer to the
///   `<array>` that consumes it, so a value assigned anywhere
///   else reds. That closes the realistic drift — a hand-typed
///   list, an emptied array, a repointed directory — because each
///   of those has to touch one of the three.
/// - It still cannot see a *runtime* failure of the derivation (a
///   glob that matches nothing on some machine, a `basename` that
///   yields something unexpected). Proving that needs the built
///   artifact, which means running a signing-and-notarization
///   script from the test suite. If this guard is ever
///   strengthened, that is the direction: parse the emitted plist
///   with `PropertyListSerialization` and compare its
///   `CFBundleLocalizations` set against a `FileManager` listing
///   of `Resources/Locales`.
@Suite("App plist localizations")
struct AppPlistLocalizationTests {
    /// Routed through the shared helper rather than re-deriving
    /// the root: the sibling script-reading suites all use it, and
    /// a hand-counted `deletingLastPathComponent` chain is exactly
    /// the depth hazard it exists to hold in one place.
    private static var buildScript: URL {
        scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("build-app.sh")
    }

    private func source() throws -> String {
        try String(
            contentsOf: Self.buildScript,
            encoding: .utf8
        )
    }

    /// The array's contents, between its own `<array>` tags.
    private func localizationsArray() throws -> String {
        let script = try source()
        let key = try #require(
            script.range(of: "<key>CFBundleLocalizations</key>"),
            "the plist declares no CFBundleLocalizations"
        )
        let tail = key.upperBound..<script.endIndex
        let open = try #require(
            script.range(of: "<array>", range: tail),
            "CFBundleLocalizations is not followed by an array"
        )
        let rest = open.upperBound..<script.endIndex
        let close = try #require(
            script.range(of: "</array>", range: rest),
            "the CFBundleLocalizations array is never closed"
        )
        return String(script[open.upperBound..<close.lowerBound])
    }

    @Test("The plist declares the languages the app speaks")
    func declaresLocalizations() throws {
        _ = try localizationsArray()
    }

    /// The array holds the expansion and nothing else.
    ///
    /// Both halves are asserted, and the first is not decoration:
    /// an **empty** array satisfies "no typed locale in here"
    /// perfectly, and ships a plist declaring zero localizations —
    /// which is #659 verbatim, macOS falling straight back to the
    /// development region. Asserting only the residue let this
    /// test pass against exactly the bug it exists to prevent.
    @Test("The locale list is derived, never typed out")
    func derivesRatherThanTypes() throws {
        let array = try localizationsArray()
        #expect(array.contains("$LOCALE_KEYS"))
        let residue =
            array
            .replacingOccurrences(of: "$LOCALE_KEYS", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(residue.isEmpty)
    }

    /// `LOCALE_KEYS` is assigned exactly twice — emptied once,
    /// then appended to from the glob — so the value the `<array>`
    /// expands cannot have come from anywhere but the catalog
    /// directory.
    ///
    /// Without this the rest of the suite is three disconnected
    /// string lookups: leave the directory and the glob untouched,
    /// add `LOCALE_KEYS="<string>de</string>"` after the loop, and
    /// every other check here still passes while the bundle ships
    /// a hand-typed two-locale list.
    @Test("Nothing assigns the locale list but the glob")
    func onlyTheGlobAssignsTheList() throws {
        let assignments = try source()
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("LOCALE_KEYS=") }
        #expect(
            assignments == [
                #"LOCALE_KEYS="""#,
                #"LOCALE_KEYS="$LOCALE_KEYS"#,
            ]
        )
    }

    /// And the glob must read the same directory `LocaleCatalog`
    /// reads at runtime, so the bundle's claim and the app's
    /// behavior cannot disagree.
    @Test("The derivation globs the shipped catalog directory")
    func readsTheCatalogDirectory() throws {
        let script = try source()
        #expect(
            script.contains(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
        )
        #expect(script.contains(#""$LOCALES"/*.json"#))
        // The heredoc delimiter must stay UNQUOTED. Quote it
        // (`<<'PLISTEOF'`) and the shell stops expanding the body,
        // so the plist ships the literal text `$LOCALE_KEYS` while
        // every other check here still passes — the array is
        // present, derived-looking, and completely inert.
        #expect(script.contains(#"<<PLISTEOF"#))
        #expect(!script.contains(#"<<'PLISTEOF'"#))
        // The appended value is the globbed filename's stem, not
        // a literal — the link between the loop and the list.
        #expect(
            script.contains(
                #"code="$(basename "$locale_file" .json)""#
            )
        )
    }

    /// The glob must REFUSE a translator worksheet, not list it.
    /// This is the second copy of the `missing_*` rule (the first
    /// is `validate_locale_files` in `scripts/extract-keys`), it
    /// is in the one language nothing else here scans, and it
    /// runs on the one machine `packaging-and-release.md` says
    /// such a failure is invisible on — a locally built `.app`
    /// would claim a language called `missing_de` while SwiftPM's
    /// `.copy` carried the worksheet into the bundle.
    ///
    /// Skipping it instead would be worse than not checking: the
    /// script would print, exit 0, and let `codesign` seal a
    /// bundle carrying the worksheet, while the plist it emitted
    /// looked perfectly right. So both halves are pinned — the
    /// case arm, and that its body **leaves the script** rather
    /// than `continue`-ing the loop.
    ///
    /// The window is bounded by the arm's own `;;` terminator,
    /// not by a character count. A 400-character window shipped
    /// here first and was inert: it reached eight lines past the
    /// `esac` and matched the `exit 1` belonging to the
    /// empty-list guard below, so the `continue` mutation — the
    /// actual defect — passed green.
    ///
    /// Still a source scan, so the runtime half is out of reach:
    /// it cannot see a glob that matches nothing on some machine,
    /// and it says nothing about SwiftPM's `.copy`, which ships
    /// whatever is in the directory whatever the plist claims.
    /// Executing this would mean running a signing script from
    /// the suite; `LocaleWorksheetRejectionTests` covers the
    /// executable half of the same rule in `extract-keys`.
    @Test("The locale glob refuses a worksheet")
    func globRejectsAWorksheet() throws {
        let script = try source()
        #expect(script.contains("missing_*)"))
        let arm =
            script
            .components(separatedBy: "missing_*)")
            .dropFirst().first
        let body = try #require(arm, "the case arm is gone")
        let end = try #require(
            body.range(of: ";;"),
            "the case arm never terminates"
        )
        let head = String(body[body.startIndex..<end.lowerBound])
        #expect(head.contains("exit 1"))
        #expect(!head.contains("continue"))
        #expect(head.contains("locale-worksheets/"))
    }
}
