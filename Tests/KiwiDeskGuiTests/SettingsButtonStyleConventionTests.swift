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
/// `.bordered`, sealed to its neutralisation (#771) — and
/// `kiwiProminentButton()` names one the same way: it IS
/// `KiwiProminentButtonStyle`, sealed to the `accentInk` label
/// white-on-kiwi cannot carry (#828). The count reads all three
/// spellings.
@Suite("Settings button style convention")
struct SettingsButtonStyleConventionTests {
    /// The trees this guard covers — `ChromeScanRoots`, which
    /// is the ONE list of "which GUI trees draw chrome". It was
    /// hand-copied into five suites when the Onboarding tree
    /// joined (#828), which is five registers a sixth tree has
    /// to be added to and four places for it to be forgotten.
    private var scanRoots: [URL] {
        ChromeScanRoots.urls(from: #filePath)
    }

    private func scannedSources() throws -> [URL] {
        try ChromeScanRoots.sources(from: #filePath)
    }

    @Test("every scan root is actually read")
    func everyScanRootIsRead() throws {
        for root in scanRoots {
            #expect(
                !(try SourceScan.swiftSources(under: root))
                    .isEmpty,
                Comment(
                    rawValue: "\(root.lastPathComponent) yielded "
                        + "no Swift files — this guard no longer "
                        + "covers that tree"
                )
            )
        }
        // Derived from what the scan READ, never from the
        // literal list: deleting a root leaves the loop above
        // green, having faithfully checked whatever remains.
        #expect(
            try scannedSources().contains {
                $0.path.contains("/Onboarding/")
            }
        )
    }

    @Test("every action button names its style")
    func actionButtonsNameTheirStyle() throws {
        var scannedFiles = 0
        var totalUnexcludedButtons = 0
        var seenNames: Set<String> = []

        for file in try scannedSources() {
            scannedFiles += 1
            let name = file.lastPathComponent
            seenNames.insert(name)
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

            // Both seals count as naming a style: each applies
            // one inside itself — `.bordered` plus its
            // neutralisation in `settingsActionButton()` (#771),
            // `KiwiProminentButtonStyle` plus its `accentInk`
            // label in `kiwiProminentButton()` (#828).
            let styles =
                source.occurrences(of: ".buttonStyle(")
                + source.occurrences(of: ".settingsActionButton()")
                + source.occurrences(of: ".kiwiProminentButton()")
            let exempt = unstyledExempt[name]?.count ?? 0
            let extraStyles = stylesOnNonButtons[name]?.count ?? 0

            // **The entry's stated STYLE is read, not just its
            // count.** guard-prover found the reason fields inert
            // (2026-08-17): the arithmetic uses `count` alone, so
            // swapping a file's extra style for a different one
            // keeps this suite green while the entry's prose names
            // a modifier the file no longer holds. That is exactly
            // the defect #859 hand-corrected one commit earlier —
            // an entry reading "Picker taking plain style" in a
            // file with neither a picker nor a `.plain`, right for
            // years because only the number was ever checked.
            // `SettingsBorderedSealTests`' entries name a token
            // that IS the reason; these now do too.
            // The exemption's own NEEDLE has to still be findable,
            // for the reason below: guard-prover found this map's
            // third field read by nothing (2026-08-17), so an
            // entry could argue at length about a symbol the file
            // no longer contains. Presence rather than a count —
            // a needle is a symbol name and appears at both its
            // declaration and its use, unlike a style spelling.
            if let entry = unstyledExempt[name] {
                #expect(
                    source.occurrences(of: entry.needle) > 0,
                    Comment(
                        rawValue:
                            "\(name)'s exemption rests on "
                            + "`\(entry.needle)` (\(entry.why)), "
                            + "which the file no longer contains — "
                            + "the count may still balance while "
                            + "the reason has gone"
                    )
                )
            }

            if let entry = stylesOnNonButtons[name] {
                #expect(
                    source.occurrences(of: entry.style)
                        == entry.count,
                    Comment(
                        rawValue:
                            "\(name)'s exemption says \(entry.count)"
                            + " × `\(entry.style)` (\(entry.why)), "
                            + "which the file no longer matches — "
                            + "the count may still balance while "
                            + "the reason has gone stale"
                    )
                )
            }

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

        // An exemption for a DELETED file leaves dead prose: both
        // maps are read as `map[name]` per scanned file, so a
        // rename reds through the arithmetic while an outright
        // deletion is never looked up (guard-prover, 2026-08-17).
        // Only the keys' side can see that.
        let exemptedFiles =
            Set(unstyledExempt.keys)
            .union(Set(stylesOnNonButtons.keys))
        for name in exemptedFiles {
            #expect(
                seenNames.contains(name),
                Comment(
                    rawValue:
                        "\(name) is exempted here and was not "
                        + "scanned — the file is gone or moved out "
                        + "of the roots, and its exemption now "
                        + "argues about nothing"
                )
            )
        }
    }
}
