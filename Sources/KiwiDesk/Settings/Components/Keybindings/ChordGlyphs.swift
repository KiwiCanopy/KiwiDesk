import Foundation
import KiwiDeskCore

/// A chord as the GUI draws it (#2601 ▸ Ruling, amended): Core's
/// glyphs, a run of same-side modifiers led by its side as a word
/// — `Left ⌃⌥ J`, `Right ⌘ H` — and an either-side chord as plain
/// glyphs. The one door from `ComboSymbols` to a drawn chord
/// (`ChordGlyphsSeamTests`): Core names a side by its letter, the
/// GUI narrates it (#96).
@MainActor
enum ChordGlyphs {
    static func render(
        _ combo: KeyCombo,
        layoutChar: (UInt32) -> String?
    ) -> String {
        words(ComboSymbols.render(combo, layoutChar: layoutChar))
    }

    static func modifiers(_ modifiers: HotkeyModifiers) -> String {
        words(ComboSymbols.modifierSymbols(modifiers))
    }

    /// What stands between drawn modifiers and their key: a space
    /// where a side is drawn as a word, so the word stays with its
    /// run — read off the drawing itself, so the two never differ.
    static func separator(_ modifiers: HotkeyModifiers) -> String {
        let glyphs = ComboSymbols.modifierSymbols(modifiers)
        return words(glyphs) == glyphs ? "" : " "
    }

    /// A side's word around a run of glyphs, as the catalog frames
    /// it.
    static func word(_ side: ModifierSide, _ run: String) -> String {
        switch side {
        case .left: L("chord.side.left", "Left %1$@", run)
        case .right: L("chord.side.right", "Right %1$@", run)
        }
    }

    /// The modifier glyphs Core draws, for readers of a drawn chord.
    static let kinds: [Character: ModifierKind] = Dictionary(
        uniqueKeysWithValues: ModifierKind.allCases.map {
            (Character(ComboSymbols.glyph(of: $0)), $0)
        }
    )

    /// Core's lettered glyphs (`R⌘H`) with each same-side run
    /// named once; unchanged where no modifier keeps a side.
    private static func words(_ glyphs: String) -> String {
        let chars = Array(glyphs)
        var pieces: [String] = []
        var run = ""
        var runSide: ModifierSide?
        var sided = false
        func closeRun() {
            guard !run.isEmpty else { return }
            pieces.append(runSide.map { word($0, run) } ?? run)
            run = ""
        }
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if String(char) == ComboSymbols.hyperGlyph {
                closeRun()
                pieces.append(String(char))
                runSide = nil
                index += 1
            } else if kinds[char] != nil {
                if runSide != nil { closeRun() }
                runSide = nil
                run.append(char)
                index += 1
            } else if let side = sides[char], index + 1 < chars.count,
                kinds[chars[index + 1]] != nil
            {
                if runSide != side { closeRun() }
                runSide = side
                sided = true
                run.append(chars[index + 1])
                index += 2
            } else {
                break
            }
        }
        guard sided else { return glyphs }
        closeRun()
        let key = String(chars[index...])
        return (pieces + (key.isEmpty ? [] : [key]))
            .joined(separator: " ")
    }

    private static let sides: [Character: ModifierSide] = Dictionary(
        uniqueKeysWithValues: ModifierSide.allCases.map {
            (Character(ComboSymbols.sideLetter($0)), $0)
        }
    )
}
