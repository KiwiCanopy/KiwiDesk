import Foundation

/// Splits `init.lua` into the app-managed block and the user's
/// own code around it, and merges a freshly generated block
/// back in without touching anything else.
///
/// The GUI owns exactly one delimited region; everything a user
/// hand-writes outside it survives a "Save". When meaningful
/// Lua exists outside the region, the GUI shows the raw code
/// editor instead of the visual controls (05_GUI_Concept §2).
public enum ManagedConfig {
    public static let beginMarker =
        "-- >>> KiwiDesk managed block "
        + "(edit in the app, not by hand) >>>"
    public static let endMarker =
        "-- <<< KiwiDesk managed block <<<"

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

    /// Drops any line that is itself a block marker.
    private static func stripMarkers(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .filter {
                let line = $0.trimmed
                return line != beginMarker && line != endMarker
            }
            .joined(separator: "\n")
    }

    /// Whether the code outside the managed block contains
    /// anything other than blank lines and comments. Such a
    /// file cannot be fully represented by the visual editor,
    /// so the GUI falls back to the Lua editor.
    public static func hasForeignCode(_ source: String) -> Bool {
        let split = split(source)
        return isCode(split.before) || isCode(split.after)
    }

    /// True if the text holds a line that is not blank and not
    /// a full-line comment (`-- ...`).
    private static func isCode(_ text: String) -> Bool {
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmed
            guard !trimmed.isEmpty else { continue }
            if !trimmed.hasPrefix("--") { return true }
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
