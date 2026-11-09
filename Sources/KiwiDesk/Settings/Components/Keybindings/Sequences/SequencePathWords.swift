import Foundation
import KiwiDeskCore

/// A key sequence's path drawn as one chord run, "⌃⌥Space → W → H"
/// (#1871): the Shortcuts rows' "Also" caption and KiwiHub's
/// Shortcuts side both read it.
@MainActor
enum SequencePathWords {
    /// The stored path, leader first, each chord drawn.
    static func drawn(_ path: [String]) -> String {
        path.map(KeySequenceHint.drawn).joined(separator: " \u{2192} ")
    }

    /// The path as VoiceOver reads it, each chord in words.
    static func spoken(_ path: [String]) -> String {
        path.map { SidedChordWords.label(KeySequenceHint.drawn($0)) }
            .joined(separator: ", ")
    }

    /// The end keys among `rows`' sequences that run `command`.
    static func endKeys(
        running command: NavCommand,
        in rows: [KeyBinding]
    ) -> [SequenceEndKey] {
        rows.filter(\.isSequence).flatMap(\.endKeys).filter {
            !$0.binding.lua.isEmpty && command.runs($0.binding.lua)
        }
    }

    /// The caption a row whose action a sequence also ends in wears
    /// (#1871 ▸ Shortcut rows): "Also ⌃⌥Space → W → H"; nil where no
    /// sequence runs it.
    static func also(
        running command: NavCommand,
        in rows: [KeyBinding],
        spoken: Bool = false
    ) -> String? {
        let paths = endKeys(running: command, in: rows)
            .map { spoken ? self.spoken($0.path) : drawn($0.path) }
        guard !paths.isEmpty else { return nil }
        return L(
            "shortcuts.sequence.also",
            "Also %1$@",
            LocalizedList.join(paths)
        )
    }
}
