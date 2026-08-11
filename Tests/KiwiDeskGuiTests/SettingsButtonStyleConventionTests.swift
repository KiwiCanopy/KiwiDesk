import Foundation
import Testing

@testable import KiwiDesk

/// An action button names its style.
///
/// A `Button` with no `.buttonStyle(...)` renders as a bordered
/// push button on macOS and takes the window tint, shipping green.
/// Buttons inside `Menu`, `.contextMenu`, `.confirmationDialog`
/// and `.alert` closures are styled by their containers and are
/// exempt. `settingsActionButton()` names a style too — it IS
/// `.bordered`, sealed to its neutralisation (#771) — so the
/// count below reads both spellings.
@Suite("Settings button style convention")
struct SettingsButtonStyleConventionTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// Allowed unstyled action buttons that cannot take a style
    /// for a documented reason.
    private let unstyledExempt:
        [String: (count: Int, needle: String, why: String)] = [
            "SpacesSection+Customize.swift": (
                9, "deleteConfirmActions",
                "Returned to a confirmationDialog / contextMenu, "
                    + "plus one icon affordance"
            ),
            "SpaceAssignmentChip.swift": (
                3, "contextMenu", "Returned to a menu/contextMenu builder"
            ),
            "PaletteShelf.swift": (
                3, "menuItem", "Returned to a contextMenu builder"
            ),
            // Moved out of `ColorField.swift` with the §2.1
            // split (#678 Phase 4 pass 10). The needle changed
            // with it and is the reason: the item is no longer
            // written INSIDE the `contextMenu` builder — it is
            // built once by `automaticItem` and handed to both
            // that builder and `.accessibilityActions`, which is
            // what stops the two routes from drifting. A button
            // in a shared menu-item builder is as unstyleable as
            // one written inline in the menu.
            "ColorField+AutomaticMenu.swift": (
                1, "automaticItem",
                "Menu item from the builder shared by contextMenu "
                    + "and accessibilityActions"
            ),
            "HeaderSearch.swift": (
                1, "focusShortcut", "Invisible zero-size shortcut sink"
            ),
        ]

    /// Styles applied to non-Button views (e.g. Link) that inflate
    /// the style count.
    private let stylesOnNonButtons:
        [String: (count: Int, style: String, why: String)] = [
            "GeneralSection+About.swift": (
                1, ".buttonStyle(.plain)", "Link taking plain style"
            ),
            "PresetsSection.swift": (
                1, ".buttonStyle(.plain)", "Picker taking plain style"
            ),
        ]

    @Test("every action button names its style")
    func actionButtonsNameTheirStyle() throws {
        var scannedFiles = 0
        var totalUnexcludedButtons = 0

        for file in try SourceScan.swiftSources(under: settingsDir) {
            scannedFiles += 1
            let name = file.lastPathComponent
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )

            let text = Array(source)
            var cursor = 0
            var braceDepth = 0
            var exclusionDepth: Int? = nil
            var pendingExclusion = false
            var unexcludedButtons = 0

            while cursor < text.count {
                let char = text[cursor]
                if char == "\"" {
                    cursor += 1
                    while cursor < text.count, text[cursor] != "\"" {
                        if text[cursor] == "\\" { cursor += 1 }
                        cursor += 1
                    }
                    if cursor < text.count { cursor += 1 }
                    continue
                }

                if char == "{" {
                    braceDepth += 1
                    if pendingExclusion {
                        if exclusionDepth == nil {
                            exclusionDepth = braceDepth
                        }
                        pendingExclusion = false
                    }
                    cursor += 1
                    continue
                }

                if char == "}" {
                    if let ed = exclusionDepth, braceDepth == ed {
                        exclusionDepth = nil
                    }
                    braceDepth -= 1
                    cursor += 1
                    continue
                }

                func match(keyword: String, isWord: Bool) -> Bool {
                    let kwArray = Array(keyword)
                    if cursor + kwArray.count > text.count { return false }

                    for i in 0..<kwArray.count {
                        if text[cursor + i] != kwArray[i] { return false }
                    }

                    if isWord {
                        let prev = cursor > 0 ? text[cursor - 1] : " "
                        let next =
                            cursor + kwArray.count < text.count
                            ? text[cursor + kwArray.count] : " "
                        let prevIsIdent =
                            prev.isLetter || prev.isNumber || prev == "_"
                            || prev == "."
                        let nextIsIdent =
                            next.isLetter || next.isNumber || next == "_"
                        return !prevIsIdent && !nextIsIdent
                    }
                    return true
                }

                let isMenu = match(keyword: "Menu", isWord: true)
                let isContextMenu = match(
                    keyword: ".contextMenu",
                    isWord: false
                )
                let isConfirm = match(
                    keyword: ".confirmationDialog",
                    isWord: false
                )
                let isAlert = match(keyword: ".alert", isWord: false)

                if isMenu || isContextMenu || isConfirm || isAlert {
                    let kwLen =
                        isMenu
                        ? 4 : (isContextMenu ? 12 : (isConfirm ? 19 : 6))
                    var tempCursor = cursor + kwLen

                    while tempCursor < text.count,
                        text[tempCursor].isWhitespace
                    { tempCursor += 1 }

                    if tempCursor < text.count, text[tempCursor] == "(" {
                        _ = SourceScan.balanced(
                            text,
                            from: &tempCursor,
                            open: "(",
                            close: ")"
                        )
                        while tempCursor < text.count,
                            text[tempCursor].isWhitespace
                        { tempCursor += 1 }
                    }

                    if tempCursor < text.count, text[tempCursor] == "{" {
                        pendingExclusion = true
                        cursor = tempCursor
                        continue
                    }

                    cursor += kwLen
                    continue
                }

                if match(keyword: "Button", isWord: true) {
                    if exclusionDepth == nil {
                        unexcludedButtons += 1
                    }
                    cursor += 6
                    continue
                }

                cursor += 1
            }

            // The seal counts as naming a style: it applies
            // `.bordered` (plus the neutralisation) inside
            // `settingsActionButton()` (#771).
            let styles =
                source.occurrences(of: ".buttonStyle(")
                + source.occurrences(of: ".settingsActionButton()")
            let exempt = unstyledExempt[name]?.count ?? 0
            let extraStyles = stylesOnNonButtons[name]?.count ?? 0

            totalUnexcludedButtons += unexcludedButtons

            #expect(
                unexcludedButtons == (styles - extraStyles) + exempt,
                Comment(
                    rawValue:
                        "\(name) has \(unexcludedButtons) "
                        + "action button(s) outside menus and "
                        + "alerts but \(styles) explicit "
                        + "`.buttonStyle(...)` (\(extraStyles) on "
                        + "non-buttons, \(exempt) exempt) — every "
                        + "Settings action button names its style "
                        + "or it defaults to the window tint."
                )
            )
        }

        #expect(scannedFiles > 50, "Scan must look at Settings files")
        #expect(totalUnexcludedButtons > 0, "Scan must find action buttons")
    }
}
