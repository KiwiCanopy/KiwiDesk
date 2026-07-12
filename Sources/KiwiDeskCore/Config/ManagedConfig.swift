import Foundation

/// Recognizes the legacy app-managed block in `init.lua` and
/// classifies the code around it (#55: the app no longer
/// GENERATES a block — `gui.json` and profiles are loaded
/// directly, and `init.lua` is hooks-only). The split stays so
/// a stale block from an earlier version keeps being treated
/// as app-owned (inert, never "foreign") until the user
/// deletes it by hand — re-saving is the migration.
///
/// The GUI only falls back to the raw Lua editor when code
/// outside a (stale) block touches the managed vocabulary —
/// verbs the GUI owns in `gui.json`. Harmless custom Lua
/// (print calls, debug hooks, sketchybar integrations)
/// coexists with the visual editor; it shows an informational
/// banner instead of locking the user out.
public enum ManagedConfig {
    public static let beginMarker =
        "-- >>> KiwiDesk managed block "
        + "(edit in the app, not by hand) >>>"
    public static let endMarker =
        "-- <<< KiwiDesk managed block <<<"

    // MARK: - Managed vocabulary

    /// Tokens matched against non-comment lines outside the
    /// (stale) managed block (see `touchesManagedVocabulary`).
    /// A match forces the raw editor because the GUI cannot
    /// safely co-own that vocabulary — it owns app rules,
    /// float rules, keybindings, and profile bindings in
    /// `gui.json` (#55). Harmless custom Lua (no matching
    /// token) coexists with the visual editor.
    ///
    /// Matching rules (see `lineMatchesToken`):
    /// - Tokens ending with `(` (method calls): optional
    ///   whitespace before `(` is collapsed first, so
    ///   `KiwiDesk.bind (` also matches `KiwiDesk.bind(`.
    /// - Bare-identifier tokens (`app_rules`, `float_rules`):
    ///   require a word boundary and `\s*=` after the token
    ///   so a substring inside a longer identifier
    ///   (`app_rules_count`) or a string literal
    ///   (`"app_rules"`) does not match.
    ///
    /// Known limitation: receiver aliasing
    /// (`local K = KiwiDesk; K.bind(…)`) escapes detection.
    /// Token-based scanning (not full Lua parsing) is a
    /// deliberate pre-release tradeoff. Post-#55 the stakes:
    /// an evading bind is registered by `init.lua`, then
    /// silently unregistered when the structured loader
    /// resets — keep bindings in ONE home (O7).
    public static let managedTokens: [String] = [
        "app_rules",
        "float_rules",
        "KiwiDesk.bind(",
        "KiwiDesk.define_mode(",
        "KiwiDesk.bind_profile_to_native_space(",
        "KiwiDesk.set_track_advanced(",
    ]

    // MARK: - Split / merge

    /// The three regions of a config file. `managed` excludes
    /// the marker lines; it is nil when no block is present.
    public struct Split: Equatable {
        public var before: String
        public var managed: String?
        public var after: String
    }

    /// Divides `source` on the marker lines. A file without
    /// markers is entirely `before` (managed nil, after empty).
    public static func split(_ source: String) -> Split {
        let lines = source.components(separatedBy: "\n")
        guard
            let begin = lines.firstIndex(where: {
                $0.trimmed == beginMarker
            }),
            let end = lines[begin...].firstIndex(where: {
                $0.trimmed == endMarker
            })
        else {
            return Split(
                before: source,
                managed: nil,
                after: ""
            )
        }
        let before = lines[..<begin].joined(separator: "\n")
        let managed = lines[(begin + 1)..<end]
            .joined(separator: "\n")
        let after = lines[(end + 1)...].joined(separator: "\n")
        return Split(
            before: before,
            managed: managed,
            after: after
        )
    }

    /// Builds an "adopted" file: the user's entire previous
    /// config, preserved verbatim but commented out (so it is
    /// inert). Used when migrating a hand-written config into
    /// GUI management — nothing is dropped or reordered, and
    /// even old marker lines are safe because every original
    /// line is prefixed with `-- `. No managed block is
    /// generated (#55): the app owns the settings in
    /// `gui.json`, and `init.lua` stays hooks-only.
    public static func adopt(
        original: String,
        date: String
    ) -> String {
        let commented =
            original
            .components(separatedBy: "\n")
            .map { $0.isEmpty ? "--" : "-- " + $0 }
            .joined(separator: "\n")
        let header = [
            "-- Previous configuration, adopted by KiwiDesk on "
                + date + ".",
            "-- The app now manages these settings itself "
                + "(gui.json);",
            "-- recovered keybindings appear in the "
                + "Keybindings tab.",
            "-- Anything below stays inert — delete this "
                + "backup once",
            "-- you no longer need it.",
        ].joined(separator: "\n")
        return header + "\n" + commented + "\n"
    }

    // MARK: - Foreign-code detection

    /// Whether code outside the managed block touches the GUI's
    /// managed vocabulary — verbs the GUI itself writes into the
    /// block (`app_rules`, `float_rules`, `KiwiDesk.bind(`,
    /// etc.). When `true` the visual editor cannot safely co-own
    /// those constructs, so it yields to the raw Lua editor.
    ///
    /// Harmless custom Lua that does NOT touch any managed token
    /// returns `false` here (the visual editor stays active) and
    /// `true` from `hasCustomCode(_:)` (a banner is shown).
    public static func hasForeignCode(_ source: String) -> Bool {
        classify(source).foreign
    }

    /// Whether any non-blank, non-comment Lua exists outside the
    /// managed block. This includes harmless code that does NOT
    /// touch the managed vocabulary. Used by the GUI to show an
    /// informational banner while keeping the visual editor
    /// active.
    ///
    /// When `hasForeignCode(_:)` is `true`, this is also `true`
    /// — every file that forces the raw editor also has custom
    /// code — but the converse does not hold.
    public static func hasCustomCode(_ source: String) -> Bool {
        classify(source).custom
    }

    /// Classifies a config source in a single scan: returns
    /// both `foreign` and `custom` flags without reading the
    /// file twice. `foreign` implies `custom` by construction.
    ///
    /// This is the **single definition** of the foreign/custom
    /// signal; `hasForeignCode`/`hasCustomCode` are thin
    /// wrappers over it, so the "one ownership predicate"
    /// invariant (AGENTS.md §5) holds structurally — there is
    /// no second composition to keep in lockstep. Prefer
    /// calling this directly when the source is already in
    /// memory (e.g. `SettingsModel.reload()`).
    public static func classify(
        _ source: String
    ) -> (foreign: Bool, custom: Bool) {
        let sp = split(source)
        let foreign =
            touchesManagedVocabulary(sp.before)
            || touchesManagedVocabulary(sp.after)
        let custom =
            foreign
            || isCode(sp.before)
            || isCode(sp.after)
        return (foreign: foreign, custom: custom)
    }

    // MARK: - Internals

    /// True if `text` holds a line that is not blank and not a
    /// full-line Lua comment (lines starting with `--`).
    ///
    /// Known limitation: `--[[ … ]]` block comment interior
    /// lines that don't start with `--` are treated as code
    /// by this line-by-line scan. The behavior is
    /// over-conservative (not dangerous); it is pinned by
    /// `ManagedConfigTests.blockCommentInteriorIsTreatedAsCode`.
    private static func isCode(_ text: String) -> Bool {
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmed
            guard !t.isEmpty else { continue }
            if !t.hasPrefix("--") { return true }
        }
        return false
    }

    /// True if any non-blank, non-comment line in `text`
    /// contains a managed-vocabulary token (matched via
    /// `lineMatchesToken` for token-type-aware rules).
    private static func touchesManagedVocabulary(
        _ text: String
    ) -> Bool {
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmed
            guard !t.isEmpty else { continue }
            if t.hasPrefix("--") { continue }
            for token in managedTokens {
                if lineMatchesToken(t, token: token) {
                    return true
                }
            }
        }
        return false
    }

    /// Matches `line` against `token` with token-type-aware
    /// rules:
    /// - Tokens ending with `(` (method calls): optional
    ///   whitespace before `(` is collapsed first so that
    ///   `KiwiDesk.bind ("alt+h", …)` matches the token
    ///   `KiwiDesk.bind(`.
    /// - Bare-identifier tokens (`app_rules`, `float_rules`):
    ///   a word boundary followed by `\s*=` is required so
    ///   that a substring inside a longer identifier
    ///   (`app_rules_count`) or inside a string literal
    ///   (`"app_rules"`) does not produce a false positive.
    private static func lineMatchesToken(
        _ line: String,
        token: String
    ) -> Bool {
        if token.hasSuffix("(") {
            // Collapse whitespace immediately before ( so
            // `KiwiDesk.bind (` also matches `KiwiDesk.bind(`.
            let norm = line.replacingOccurrences(
                of: #"\s+\("#,
                with: "(",
                options: .regularExpression
            )
            return norm.contains(token)
        }
        // Bare-identifier tokens: require word boundary + =
        // so app_rules_count and "app_rules" don't match.
        let pat =
            #"\b"#
            + NSRegularExpression.escapedPattern(for: token)
            + #"\s*="#
        return line.range(
            of: pat,
            options: .regularExpression
        ) != nil
    }
}

extension StringProtocol {
    /// Trims spaces, tabs, and line terminators (`\r`) so marker
    /// matching and the foreign-code scan survive CRLF files.
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
