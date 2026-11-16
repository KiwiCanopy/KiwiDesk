import Foundation
import Testing

/// A Settings-tree view that reads macOS's Reduce Motion keeps it
/// wherever it is mounted, so one mounted in KiwiHub, the tour or
/// another desk surface plays motion under Off (#3252, the scope
/// switch's `SegmentedPicker`). Such a shared view reads
/// `\.kiwiDeskReduceMotion`, which the Settings window writes from
/// macOS's setting and every other host from `ReduceMotion.isOn`.
///
/// The scan is transitive inside Settings, file by file: a file
/// that mounts a reader's view type (`View`, `ViewModifier`, a
/// style) or calls its `extension View` modifier carries the reader
/// with it. Trade: a file is one node, so a file holding a reader
/// and an unrelated view reds for the unrelated one, and names are
/// matched as words over comment-stripped source; content handed in
/// through a generic parameter or `AnyView` is not followed.
@Suite("Reduce Motion reach (#3252)")
struct ReduceMotionReachTests {
    private static let needle = "accessibilityReduceMotion"
    private static let settings = "Sources/KiwiDesk/Settings/"

    private struct Source {
        let path: String
        let text: String
        /// Every identifier spelled, and those spelled after a dot.
        let words: Set<String>
        let dotted: Set<String>
        let types: Set<String>
        let modifiers: Set<String>

        func uses(_ other: Source) -> Bool {
            !words.isDisjoint(with: other.types)
                || !dotted.isDisjoint(with: other.modifiers)
        }
    }

    private static func captures(
        _ pattern: String,
        in text: String
    ) -> Set<String> {
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        return Set(
            regex.matches(in: text, range: range).compactMap {
                Range($0.range(at: 1), in: text).map { String(text[$0]) }
            }
        )
    }

    /// A type that draws: a `View`, a `ViewModifier` or a style.
    private static let viewType =
        "(?:struct|class|enum)\\s+([A-Z]\\w*)\\s*(?:<[^>{]*>)?\\s*:"
        + "[^{]*\\b(?:View|ViewModifier|\\w*Style)\\b"

    /// The non-private functions declared inside `extension View
    /// { … }` blocks, walked in UTF-16 units as `NSRange` counts.
    private static func viewExtensionFuncs(in text: String) -> Set<String> {
        let units = text as NSString
        var names: Set<String> = []
        let regex = try! NSRegularExpression(
            pattern: "extension\\s+View\\b[^{]*\\{"
        )
        let range = NSRange(location: 0, length: units.length)
        for match in regex.matches(in: text, range: range) {
            let start = NSMaxRange(match.range)
            var depth = 1
            var end = start
            while end < units.length, depth > 0 {
                let unit = units.character(at: end)
                if unit == 0x7B { depth += 1 }
                if unit == 0x7D { depth -= 1 }
                end += 1
            }
            let block = units.substring(
                with: NSRange(location: start, length: end - start)
            )
            let open = block.components(separatedBy: "\n")
                .filter { !$0.contains("private") }
                .joined(separator: "\n")
            names.formUnion(
                captures("func\\s+([a-z]\\w*)\\s*[(<]", in: open)
            )
        }
        return names
    }

    @Test("no macOS-only Reduce Motion reader leaves Settings")
    func readersStayInSettings() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let files = try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk")
        )
        let sources = try files.map { file in
            let text = try SourceScan.strippedSource(at: file)
            let open = text.components(separatedBy: "\n")
                .filter { !$0.contains("private") }
                .joined(separator: "\n")
            return Source(
                path: String(file.path.dropFirst(root.path.count + 1)),
                text: text,
                words: Self.captures("([A-Za-z_]\\w*)", in: text),
                dotted: Self.captures("\\.([a-z]\\w*)\\s*\\(", in: text),
                types: Self.captures(Self.viewType, in: open),
                modifiers: Self.viewExtensionFuncs(in: text)
            )
        }
        let inside = sources.filter { $0.path.hasPrefix(Self.settings) }
        let outside = sources.filter { !$0.path.hasPrefix(Self.settings) }
        var reach = inside.filter { $0.text.contains(Self.needle) }
        #expect(!reach.isEmpty)
        var grew = true
        while grew {
            let known = Set(reach.map(\.path))
            let more = inside.filter { file in
                !known.contains(file.path)
                    && reach.contains { file.uses($0) }
            }
            reach += more
            grew = !more.isEmpty
        }
        var leaks: [String] = []
        for user in outside {
            for reader in reach where user.uses(reader) {
                leaks.append("\(user.path) mounts \(reader.path)")
            }
        }
        #expect(leaks.isEmpty, "\(leaks)")
    }

    /// Every SwiftUI hosting root, by file and count, and how it
    /// hands its views the value: a root that writes nothing leaves
    /// them on the key's default, still, so a new root states its
    /// answer here, and one that writes it joins
    /// `ReduceMotionHomeTests`' `hostsAreWired`. Residue: a reason
    /// ("mounts no reader") is prose nothing checks.
    private static let hosts: [String: (Int, String)] = [
        "AppDelegate+Onboarding.swift": (1, "ReduceMotion.isOn at open"),
        "BootNotice/BootNoticeController.swift": (1, "its model, at show"),
        "ConfigIssuesWindow.swift": (1, "mounts no reader"),
        "CuePlate/CuePlateController.swift": (1, "its model, at show"),
        "Jump/JumpPanelController.swift": (1, "PanelPresence, at show"),
        "Settings/SettingsWindowController.swift":
            (1, "SettingsView writes macOS's setting, live"),
        "Shortcuts/KeySequenceHintController.swift":
            (1, "ReduceMotion.isOn at draw"),
        "Updates/UpdateCheckingWindowController.swift":
            (1, "a measuring probe; the window is UpdateWindowChrome's"),
        "Updates/UpdateWindowChrome.swift":
            (2, "ReduceMotion.isOn at show, and a measuring probe"),
    ]

    @Test("every hosting root states how it hands the value")
    func hostsAreRegistered() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        // A generic spelling counts too, so a typed root is seen.
        let spellings = [
            "NSHostingView(", "NSHostingController(",
            "NSHostingView<", "NSHostingController<",
        ]
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let text = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
            let count = spellings.reduce(0) {
                $0 + text.occurrences(of: $1)
            }
            guard count > 0 else { continue }
            found[String(file.path.dropFirst(root.path.count + 1))] = count
        }
        #expect(!found.isEmpty)
        #expect(found == Self.hosts.mapValues(\.0), "\(found)")
    }
}
