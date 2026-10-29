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

    /// A drawn chord's structure: its modifier runs in order, each
    /// with its side (nil for an either-side run or the hyper
    /// glyph), then its key — the one reading `words` draws from,
    /// so a surface splitting a chord into parts never re-parses
    /// the localized string (#2777).
    struct Runs: Equatable {
        var runs: [(side: ModifierSide?, glyphs: String)]
        var key: String

        static func == (lhs: Runs, rhs: Runs) -> Bool {
            lhs.key == rhs.key
                && lhs.runs.map(\.glyphs) == rhs.runs.map(\.glyphs)
                && lhs.runs.map(\.side) == rhs.runs.map(\.side)
        }
    }

    static func runs(
        _ combo: KeyCombo,
        layoutChar: (UInt32) -> String?
    ) -> Runs {
        parse(ComboSymbols.render(combo, layoutChar: layoutChar))
    }

    /// Core's lettered glyphs (`R⌘H`) with each same-side run
    /// named once; unchanged where no modifier keeps a side.
    private static func words(_ glyphs: String) -> String {
        let parsed = parse(glyphs)
        guard parsed.runs.contains(where: { $0.side != nil }) else {
            return glyphs
        }
        let pieces = parsed.runs.map { run in
            run.side.map { word($0, run.glyphs) } ?? run.glyphs
        }
        return (pieces + (parsed.key.isEmpty ? [] : [parsed.key]))
            .joined(separator: " ")
    }

    /// Splits Core's lettered glyphs into same-side runs and the key.
    private static func parse(_ glyphs: String) -> Runs {
        let chars = Array(glyphs)
        var runs: [(side: ModifierSide?, glyphs: String)] = []
        var run = ""
        var runSide: ModifierSide?
        func closeRun() {
            guard !run.isEmpty else { return }
            runs.append((runSide, run))
            run = ""
        }
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if String(char) == ComboSymbols.hyperGlyph {
                closeRun()
                runs.append((nil, String(char)))
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
                run.append(chars[index + 1])
                index += 2
            } else {
                break
            }
        }
        closeRun()
        return Runs(runs: runs, key: String(chars[index...]))
    }

    private static let sides: [Character: ModifierSide] = Dictionary(
        uniqueKeysWithValues: ModifierSide.allCases.map {
            (Character(ComboSymbols.sideLetter($0)), $0)
        }
    )
}
