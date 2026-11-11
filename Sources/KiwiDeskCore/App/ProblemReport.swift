import Foundation

/// What "Report a problem" hands the bug form and the log export
/// (#3214): the short facts a report turns on, under the form's
/// own field ids (`bug_report.yml`) and as the exported file's
/// header. English throughout, since a maintainer reads both.
public struct ProblemReport: Sendable, Equatable {
    /// The issue form a report opens.
    public static let form = URL(
        string: "https://github.com/KiwiCanopy/KiwiDesk/issues/new"
    )!

    public var version: String
    public var macOS: String
    public var screens: Int
    public var separateSpaces: Bool

    public init(
        version: String,
        macOS: String,
        screens: Int,
        separateSpaces: Bool
    ) {
        self.version = version
        self.macOS = macOS
        self.screens = screens
        self.separateSpaces = separateSpaces
    }

    /// The screen count and the Desktop mode, one line each.
    var deskLines: [String] {
        [
            "Screens: \(screens)",
            "Displays have separate Spaces: "
                + (separateSpaces ? "on" : "off"),
        ]
    }

    /// The form's address with the facts filled in. Settings never
    /// ride here: the form is public and they name apps and paths.
    public var formURL: URL {
        var parts = URLComponents(
            url: Self.form,
            resolvingAgainstBaseURL: false
        )!
        parts.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "kiwidesk_version", value: version),
            URLQueryItem(name: "macos_version", value: macOS),
            URLQueryItem(
                name: "extra_context",
                value: deskLines.joined(separator: "\n")
            ),
        ]
        // `+` reads as a space in a form query.
        parts.percentEncodedQuery = parts.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return parts.url!
    }

    /// The exported log's header: the facts, each Space's
    /// layout, then every value that differs from what an install
    /// starts from, ended by a blank line so the log's own column
    /// header follows apart.
    public func logHeader(
        spaceLayouts: [String],
        changedSettings: [String]
    ) -> String {
        let lines =
            ["KiwiDesk \(version)", "macOS \(macOS)"] + deskLines
            + ["Space layouts:"] + Self.indented(spaceLayouts)
            + ["Settings changed from the defaults:"]
            + Self.indented(changedSettings)
        return lines.joined(separator: "\n") + "\n\n"
    }

    private static func indented(_ lines: [String]) -> [String] {
        lines.isEmpty ? ["  (none)"] : lines.map { "  \($0)" }
    }
}

/// The leaves where a live keep-document root differs from its
/// built-in default, as `pointer = JSON` lines (#3214).
enum ChangedSettings {
    static func lines(
        root: String,
        base: JSONValue?,
        live: JSONValue?
    ) -> [String] {
        KeepPointer.diff(base, live).map { path in
            let value = live.flatMap { KeepPointer.value(at: path, in: $0) }
            return KeepPointer.string([root] + path) + " = "
                + compact(value)
        }
    }

    /// `value` as one line of key-sorted JSON; a leaf the live
    /// document omits reads `unset`.
    static func compact(_ value: JSONValue?) -> String {
        guard let value else { return "unset" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return "?" }
        return String(decoding: data, as: UTF8.self)
    }
}
