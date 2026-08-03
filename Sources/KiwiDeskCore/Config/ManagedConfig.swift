import Foundation

/// Classifies `init.lua` by whether its code touches the GUI's
/// managed vocabulary (#55: the app loads `gui.json` and profiles
/// directly and treats `init.lua` as hooks-only — it neither
/// generates nor recognizes a managed block).
///
/// The GUI falls back to the raw Lua editor only when the code
/// touches the managed vocabulary — verbs the GUI owns in
/// `gui.json`. Harmless custom Lua (print calls, debug hooks,
/// sketchybar integrations) coexists with the visual editor; it
/// shows an informational banner instead of locking the user out.
///
/// Pre-release, the marker-block recognition that used to keep a
/// stale pre-#55 block "app-owned" was removed (#116): such a block
/// is now scanned like any other code, so a bind or rule inside it
/// reads as foreign — the file becomes Lua-owned (raw editor, never
/// seeded over), the safe direction. Re-saving is the migration.
public enum ManagedConfig {
    // MARK: - Managed vocabulary

    /// Tokens matched against non-comment, non-blank lines of the
    /// source (see `touchesManagedVocabulary`).
    /// A match forces the raw editor because the GUI cannot
    /// safely co-own that vocabulary — it owns app rules,
    /// float/ignore rules, keybindings, and profile bindings in
    /// `gui.json` (#55). Harmless custom Lua (no matching
    /// token) coexists with the visual editor.
    ///
    /// Matching rules (see `lineMatchesToken`):
    /// - Tokens ending with `(` (method calls): optional
    ///   whitespace before `(` is collapsed first, so
    ///   `KiwiDesk.bind (` also matches `KiwiDesk.bind(`.
    /// - Bare-identifier tokens (`app_rules`, `float_rules`,
    ///   `ignore_rules`):
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
        "ignore_rules",
        "KiwiDesk.bind(",
        "KiwiDesk.define_layer(",
        "KiwiDesk.bind_profile_to_native_space(",
    ]

    // `adopt` and its selective-comment machinery live in
    // `ManagedConfig+Adopt.swift` (file-size split, §2).

    // MARK: - Foreign-code detection

    /// Whether the code touches the GUI's managed vocabulary —
    /// verbs the GUI itself owns in `gui.json` (`app_rules`,
    /// `float_rules`, `ignore_rules`, `KiwiDesk.bind(`,
    /// etc.). When `true` the visual editor cannot safely co-own
    /// those constructs, so it yields to the raw Lua editor.
    ///
    /// Harmless custom Lua that does NOT touch any managed token
    /// returns `false` here (the visual editor stays active) and
    /// `true` from `hasCustomCode(_:)` (a banner is shown).
    public static func hasForeignCode(_ source: String) -> Bool {
        classify(source).foreign
    }

    /// Whether any non-blank, non-comment Lua exists in the file.
    /// This includes harmless code that does NOT
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

    /// Whether the config declares any managed **setting** — the
    /// signal that gates the first-launch `gui.json` seed (#354).
    ///
    /// A *superset* of `hasForeignCode`: on top of the foreign
    /// tokens (rules/binds/modes) it also catches the `set_*`
    /// setting verbs — `KiwiDesk.set_gap_global`, and crucially the
    /// **namespaced** layout verbs (`bsp.set_ratio_h`,
    /// `stack.set_master_ratio`, …) — that the editor-fallback
    /// check deliberately ignores. Those verbs configure tiling
    /// directly, so a hand-written config using them is Lua-owned
    /// and must never be seeded over (the GUI defaults would
    /// silently overwrite the user's Lua settings, #354). Harmless
    /// custom Lua — event hooks (`KiwiDesk.on`/`KiwiDesk.exec`),
    /// `print`, control flow — matches nothing and returns `false`,
    /// so a hooks-only file still earns the GUI defaults.
    public static func declaresManagedSettings(
        _ source: String
    ) -> Bool {
        classify(source).foreign || hasLiveSettingVerb(source)
    }

    /// A live (non-comment) call to a `set_*` settings verb, on the
    /// `KiwiDesk` table or any layout namespace. The namespace set
    /// is `APIReference.namespaces` — the authoritative registry —
    /// so this can't drift as sub-APIs (`bsp`, `stack`, `scroll`,
    /// …) or their verbs are added. Anchoring to those known table
    /// names avoids false positives from an unrelated
    /// `foo.set_bar()`.
    private static func hasLiveSettingVerb(
        _ source: String
    ) -> Bool {
        for raw in source.components(separatedBy: "\n") {
            let line = raw.trimmed
            guard !line.isEmpty, !line.hasPrefix("--") else {
                continue
            }
            if lineHasSettingVerb(line) { return true }
        }
        return false
    }

    /// Whether one line calls a `set_*` settings verb (on the
    /// `KiwiDesk` table or a layout namespace) or `border.fit_gaps`.
    /// The **single** definition of the setting-verb vocabulary,
    /// shared by the file-level `hasLiveSettingVerb` and the
    /// per-line `lineDeclaresManaged`, so the two can't drift as
    /// verbs are added (§5 hand-mirrored-list rule).
    static func lineHasSettingVerb(_ line: String) -> Bool {
        if line.contains("KiwiDesk.set_") { return true }
        // `border.fit_gaps` is the one config-writing verb without
        // a `set_` name — it rewrites the global gap from the
        // border width (`KiwiCore+BorderCommands`), so a config
        // tuning gaps that way must not be seeded over.
        if line.contains("border.fit_gaps") { return true }
        for ns in APIReference.namespaces.keys
        where line.contains("\(ns).set_") {
            return true
        }
        return false
    }

    /// Whether one line opens a **foreign** construct — a
    /// `managedTokens` match (`KiwiDesk.bind(`, `app_rules =`, …).
    /// The per-line half of `touchesManagedVocabulary`, shared so
    /// the file-level foreign scan and `lineDeclaresManaged` use
    /// one matcher.
    static func lineMatchesForeignToken(_ line: String) -> Bool {
        for token in managedTokens
        where lineMatchesToken(line, token: token) {
            return true
        }
        return false
    }

    /// Whether a single trimmed, non-comment `line` opens a
    /// **managed** construct — a foreign token or a `set_*` setting
    /// verb — i.e. a statement `adopt` comments out because
    /// `gui.json` now owns it. The per-line union of the two
    /// vocabularies above; harmless custom Lua (hooks, `print`,
    /// helpers) matches nothing (#355). Used to classify a
    /// statement by its head line so a hook that *contains* an
    /// inner `set_` still reads as custom.
    static func lineDeclaresManaged(_ line: String) -> Bool {
        lineMatchesForeignToken(line) || lineHasSettingVerb(line)
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
        let foreign = touchesManagedVocabulary(source)
        let custom = foreign || isCode(source)
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
            if lineMatchesForeignToken(t) { return true }
        }
        return false
    }

    /// Matches `line` against `token` with token-type-aware
    /// rules:
    /// - Tokens ending with `(` (method calls): optional
    ///   whitespace before `(` is collapsed first so that
    ///   `KiwiDesk.bind ("alt+h", …)` matches the token
    ///   `KiwiDesk.bind(`.
    /// - Bare-identifier tokens (`app_rules`, `float_rules`,
    ///   `ignore_rules`):
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
    /// Trims spaces, tabs, and line terminators (`\r`) so the
    /// foreign-code scan survives CRLF files.
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
