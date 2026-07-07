import Foundation

/// Splits `init.lua` into the app-managed block and the user's
/// own code around it, and merges a freshly generated block
/// back in without touching anything else.
///
/// The GUI owns exactly one delimited region; everything a user
/// hand-writes outside it survives a "Save". The GUI only falls
/// back to the raw Lua editor when the surrounding code touches
/// the managed vocabulary — verbs the GUI itself emits. Harmless
/// custom Lua (print calls, debug hooks, sketchybar integrations)
/// coexists with the visual editor; it shows an informational
/// banner instead of locking the user out.
public enum ManagedConfig {
    public static let beginMarker =
        "-- >>> KiwiDesk managed block "
        + "(edit in the app, not by hand) >>>"
    public static let endMarker =
        "-- <<< KiwiDesk managed block <<<"

    // MARK: - Managed vocabulary

    /// Token substrings that appear in the GUI's generated
    /// managed block (derived from `LuaConfigWriter`). Code
    /// outside the block that contains one of these tokens
    /// forces the raw editor — the GUI cannot safely own
    /// the file when the same vocabulary appears in both
    /// regions. Harmless custom Lua (none of these tokens)
    /// coexists with the visual editor instead.
    ///
    /// Drift guard: `ManagedVocabularyTests` verifies that
    /// every line `LuaConfigWriter` emits is covered by at
    /// least one token here — add to this list whenever the
    /// writer gains a new top-level construct.
    public static let managedTokens: [String] = [
        "app_rules",
        "float_rules",
        "KiwiDesk.bind(",
        "KiwiDesk.define_mode(",
        "KiwiDesk.bind_profile_to_native_space(",
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

    /// Rebuilds a full config file: the user's surrounding code
    /// with a freshly wrapped managed block spliced in. If the
    /// source had no block, the new one is appended.
    public static func merge(
        block: String,
        into source: String
    ) -> String {
        let split = split(source)
        let wrapped =
            beginMarker + "\n" + block + "\n" + endMarker
        var parts: [String] = []
        // Strip any stray marker lines the surrounding regions
        // may carry (an orphaned begin without an end, a
        // duplicate marker from a partial write) so exactly one
        // canonical block survives.
        let before = stripMarkers(split.before).trimmedTrailing
        if !before.isEmpty { parts.append(before) }
        parts.append(wrapped)
        let after = stripMarkers(split.after)
            .trimmedLeadingWhitespaceLines
        if !after.isEmpty { parts.append(after) }
        return parts.joined(separator: "\n\n") + "\n"
    }

    /// Builds an "adopted" file: a fresh managed block followed
    /// by the user's entire previous config, preserved verbatim
    /// but commented out (so it is inert). Used when migrating a
    /// hand-written config into GUI management — nothing is
    /// dropped or reordered, and even old marker lines are safe
    /// because every original line is prefixed with `-- `.
    public static func adopt(
        original: String,
        block: String,
        date: String
    ) -> String {
        let wrapped =
            beginMarker + "\n" + block + "\n" + endMarker
        let commented =
            original
            .components(separatedBy: "\n")
            .map { $0.isEmpty ? "--" : "-- " + $0 }
            .joined(separator: "\n")
        let header = [
            "-- Previous configuration, adopted by KiwiDesk on "
                + date + ".",
            "-- The app now manages the settings in the block "
                + "above.",
            "-- Keybindings could not be imported automatically "
                + "— add",
            "-- them again in the Keybindings tab, then delete "
                + "this",
            "-- backup once you no longer need it.",
        ].joined(separator: "\n")
        return wrapped + "\n\n" + header + "\n" + commented
            + "\n"
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
        let split = split(source)
        return touchesManagedVocabulary(split.before)
            || touchesManagedVocabulary(split.after)
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
        let split = split(source)
        return isCode(split.before) || isCode(split.after)
    }

    // MARK: - Internals

    /// Drops any line that is itself a block marker.
    private static func stripMarkers(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .filter {
                let line = $0.trimmed
                return line != beginMarker && line != endMarker
            }
            .joined(separator: "\n")
    }

    /// True if `text` holds a line that is not blank and not a
    /// full-line comment (`-- ...`).
    private static func isCode(_ text: String) -> Bool {
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmed
            guard !t.isEmpty else { continue }
            if !t.hasPrefix("--") { return true }
        }
        return false
    }

    /// True if any non-blank, non-comment line in `text`
    /// contains a managed-vocabulary token.
    private static func touchesManagedVocabulary(
        _ text: String
    ) -> Bool {
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmed
            guard !t.isEmpty else { continue }
            if t.hasPrefix("--") { continue }
            for token in managedTokens {
                if t.contains(token) { return true }
            }
        }
        return false
    }
}

extension StringProtocol {
    /// Trims spaces, tabs, and line terminators (`\r`) so marker
    /// matching and the foreign-code scan survive CRLF files.
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    /// Drops trailing blank lines (keeps interior spacing).
    fileprivate var trimmedTrailing: String {
        var lines = components(separatedBy: "\n")
        while let last = lines.last,
            last.trimmingCharacters(in: .whitespaces).isEmpty
        {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    /// Drops leading blank lines.
    fileprivate var trimmedLeadingWhitespaceLines: String {
        var lines = components(separatedBy: "\n")
        while let first = lines.first,
            first.trimmingCharacters(in: .whitespaces).isEmpty
        {
            lines.removeFirst()
        }
        return lines.joined(separator: "\n")
    }
}
