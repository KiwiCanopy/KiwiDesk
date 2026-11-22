import KiwiDeskCore
import SwiftUI

/// The caption under an either-side row a sided row narrows
/// (#3256), "Only Right⌘⌘ runs this. Left⌘⌘ runs
/// “Show KiwiHub”.", with a Go to the other row. Quiet, never a
/// conflict: the narrower row winning is the intended precedence.
/// Drawn from Core's one `SideReach`, never a copy of the routers'
/// rule.
extension KeyRecorderField {
    var narrowingLine: RecorderCaption? {
        // A row macOS answers first runs from no side; its dead
        // caption says so alone.
        guard !recording, !isDead, let narrowing,
            let words = SideReachWords.caption(
                runs: narrowing.runs,
                taken: narrowing.taken,
                holder: narrowing.holder
            )
        else { return nil }
        return .narrowing(
            drawn: words.drawn,
            spoken: words.spoken,
            row: RecorderPreflight.rowID(narrowing.taken.by)
        )
    }

    @MainActor static var goToTitle: String {
        L("key_recorder.go_to", "Go to")
    }

}

/// A row's narrowing as its caption draws it (#3256), minted at the
/// mount, which holds the layer and the config: what still runs the
/// row, what the other row takes, and that row's name. Nil where
/// nothing narrows it, where no key reaches it (a conflict then
/// says so) or where the forms need more than one combo to say.
struct SideNarrowing: Equatable {
    let runs: KeyCombo
    let taken: SideReach.Taken
    let holder: String

    @MainActor
    static func of(
        _ binding: KeyBinding?,
        in bindings: [KeyBinding],
        config: GuiConfig,
        sides: Bool
    ) -> SideNarrowing? {
        guard let binding,
            let reach = LayerConflictMemo.reach(
                for: binding,
                in: bindings,
                sides: sides
            ),
            !reach.isDead, let runs = reach.runs,
            let taken = reach.takenBy
        else { return nil }
        return SideNarrowing(
            runs: runs,
            taken: taken,
            holder: KeybindingCatalog.localizedName(
                of: taken.by,
                config: config
            )
        )
    }
}

/// The narrowing caption's words, drawn and spoken (#3256).
@MainActor
enum SideReachWords {
    static func caption(
        runs: KeyCombo,
        taken: SideReach.Taken,
        holder: String
    ) -> (drawn: String, spoken: String)? {
        let drawnLine = L(
            "key_recorder.narrowed",
            "Only %1$@ runs this. %2$@ runs \u{201C}%3$@\u{201D}.",
            drawn(runs),
            drawn(taken.combo),
            holder
        )
        // Label-first: a spoken tap is a clause ("Right ⌘,
        // press twice") no subject slot can take in every catalog.
        let spokenLine = L(
            "key_recorder.narrowed.spoken",
            "Runs from: %1$@. \u{201C}%3$@\u{201D} takes: %2$@.",
            spoken(runs),
            spoken(taken.combo),
            holder
        )
        return (drawnLine, spokenLine)
    }

    private static func drawn(_ combo: KeyCombo) -> String {
        ChordGlyphs.render(combo, layoutChar: LayoutKeyGlyph.char)
    }

    /// A tap in its words, a chord through the one spoken door.
    private static func spoken(_ combo: KeyCombo) -> String {
        ModifierTapWords.spoken(combo)
            ?? SidedChordWords.label(drawn(combo))
    }
}
