import Foundation
import Testing

@testable import KiwiDesk

/// A jump group's `control` and `container` are two parallel
/// switches (#1520): the chip scrolls to the card titled by the
/// control, and the census mapping reads the container. This
/// suite holds the pair together at the render site — the view
/// titling its card with the group's control draws the rows the
/// census places in the group's container. It proves a witness is
/// SPELLED in that view's declaration, not that it is mounted: a
/// helper member that names the rows but is never drawn stays
/// green, so a green here reads "names", never "draws".
@Suite("Shortcuts jump group pairing")
@MainActor
struct ShortcutsJumpPairingTests {
    /// A spelling a card's view uses to draw its rows, and the
    /// census keys that spelling draws. Each witness's container
    /// is read off the census, never typed here.
    private static var witnesses: [(String, [SettingKey])] {
        let gestures = SettingsCatalog.shortcuts.gestures.childIDs
        let gestureRows = SettingKey.allCases.filter {
            guard case .key(let key) = $0.text.label else {
                return false
            }
            return gestures.contains(key)
        }
        return [
            (
                "ShortcutsRowOrder.focusAtRest",
                ShortcutsRowOrder.focusAtRest
            ),
            (
                "ShortcutsRowOrder.moveWindowsAtRest",
                ShortcutsRowOrder.moveWindowsAtRest
            ),
            (
                "ShortcutsRowOrder.sizeAndFloatAtRest",
                ShortcutsRowOrder.sizeAndFloatAtRest
            ),
            (
                "KiwiDeskKeyRows(",
                ShortcutsRowOrder.openApplicationsKiwiDesk
            ),
            (
                "SettingsCatalog.shortcuts.gestures.children",
                gestureRows
            ),
        ]
    }

    /// Every type declaration in the GUI tree, comments stripped
    /// and whitespace removed.
    private static func declarations() throws -> [String] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let opener = try NSRegularExpression(
            pattern: #"\b(?:struct|extension|enum|class) (?=[A-Z])"#
        )
        return try SourceScan.swiftSources(under: root).flatMap {
            url -> [String] in
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            let ns = text as NSString
            let starts = opener.matches(
                in: text,
                range: NSRange(location: 0, length: ns.length)
            ).map(\.range.location)
            return zip(starts, starts.dropFirst() + [ns.length]).map {
                ns.substring(with: NSRange(location: $0, length: $1 - $0))
                    .split(whereSeparator: \.isWhitespace)
                    .joined()
            }
        }
    }

    /// The catalog property spelling the group's title control.
    private static func spelling(
        of group: ShortcutsJumpGroup
    ) -> String? {
        Mirror(reflecting: SettingsCatalog.shortcuts).children.first {
            let control =
                ($0.value as? SettingsControl)
                ?? ($0.value as? AnySettingsDrawer)?.control
            return control == group.control
        }?.label
    }

    @Test("each chip's card draws its container's rows")
    func controlTitlesTheContainersCard() throws {
        let declarations = try Self.declarations()
        let witnesses = Self.witnesses
        for (_, keys) in witnesses {
            #expect(!keys.isEmpty)
        }
        let kiwiDeskRows = declarations.filter {
            $0.hasPrefix("structKiwiDeskKeyRows:")
        }
        #expect(kiwiDeskRows.count == 1)
        #expect(
            kiwiDeskRows.allSatisfy {
                $0.contains("ShortcutsRowOrder.openApplicationsKiwiDesk")
            }
        )
        for group in ShortcutsJumpGroup.allCases {
            let name = try #require(Self.spelling(of: group))
            let title = "SettingsCatalog.shortcuts.\(name)"
            let cards = declarations.filter {
                $0.contains(title + ")") || $0.contains(title + ",")
            }
            #expect(!cards.isEmpty, "\(group): no card titled \(name)")
            let drawn = Set(
                witnesses.filter { needle, _ in
                    cards.contains { $0.contains(needle) }
                }
                .flatMap { $0.1.compactMap(\.placement.container) }
            )
            #expect(
                drawn == [group.container],
                "\(group): the \(name) card draws \(drawn)"
            )
        }
    }
}
