import Foundation

/// Classifies `init.lua` by whether it touches GUI-managed vocabulary
/// (#55, #116).
public enum ManagedConfig {
    /// Tokens matched against non-comment lines that force the raw
    /// Lua editor. Known limitation: receiver aliasing
    /// (`local K = KiwiDesk; K.bind(…)`) escapes this token scan —
    /// a deliberate tradeoff, and the stakes are why bindings stay
    /// in ONE home (O7): an evading bind is registered by
    /// init.lua, then silently unregistered when the structured
    /// loader resets.
    public static let managedTokens: [String] = [
        "app_rules",
        "float_rules",
        "ignore_rules",
        "KiwiDesk.bind(",
        "KiwiDesk.define_layer(",
        "KiwiDesk.bind_profile_to_desktop(",
    ]

    /// True if code touches GUI-managed vocabulary (`gui.json` ownership).
    public static func hasForeignCode(_ source: String) -> Bool {
        classify(source).foreign
    }

    /// True if non-blank, non-comment Lua code exists in source.
    public static func hasCustomCode(_ source: String) -> Bool {
        classify(source).custom
    }

    /// Whether the config declares any managed SETTING — the
    /// first-launch seed gate (#354): a hand-written config using
    /// `set_*` verbs is Lua-owned and must never be seeded over,
    /// while a hooks-only file still earns the GUI defaults.
    public static func declaresManagedSettings(
        _ source: String
    ) -> Bool {
        classify(source).foreign || hasLiveSettingVerb(source)
    }

    /// Live call to any `set_*` settings verb on KiwiDesk or layout
    /// namespaces.
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

    /// Single definition of setting-verb vocabulary across namespaces.
    static func lineHasSettingVerb(_ line: String) -> Bool {
        if line.contains("KiwiDesk.set_") { return true }
        // `border.fit_gaps` rewrites global gap from border width.
        if line.contains("border.fit_gaps") { return true }
        for ns in APIReference.namespaces.keys
        where line.contains("\(ns).set_") {
            return true
        }
        return false
    }

    /// Whether line opens a foreign construct matching `managedTokens`.
    static func lineMatchesForeignToken(_ line: String) -> Bool {
        for token in managedTokens
        where lineMatchesToken(line, token: token) {
            return true
        }
        return false
    }

    /// Whether line opens a managed construct commented out on adopt (#355).
    static func lineDeclaresManaged(_ line: String) -> Bool {
        lineMatchesForeignToken(line) || lineHasSettingVerb(line)
    }

    /// Single-pass classifier returning (foreign, custom) flags.
    public static func classify(
        _ source: String
    ) -> (foreign: Bool, custom: Bool) {
        let foreign = touchesManagedVocabulary(source)
        let custom = foreign || isCode(source)
        return (foreign: foreign, custom: custom)
    }

    /// True if text contains non-comment code lines
    /// (`ManagedConfigTests.blockCommentInteriorIsTreatedAsCode`).
    private static func isCode(_ text: String) -> Bool {
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmed
            guard !t.isEmpty else { continue }
            if !t.hasPrefix("--") { return true }
        }
        return false
    }

    /// True if any active line matches managed vocabulary tokens.
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

    /// Matches line against token taking method parentheses and word
    /// boundaries.
    private static func lineMatchesToken(
        _ line: String,
        token: String
    ) -> Bool {
        if token.hasSuffix("(") {
            let norm = line.replacingOccurrences(
                of: #"\s+\("#,
                with: "(",
                options: .regularExpression
            )
            return norm.contains(token)
        }
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
    /// Trims whitespaces and newlines across CRLF line endings.
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
