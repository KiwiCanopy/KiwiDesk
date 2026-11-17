import Foundation
import KiwiDeskCore

/// What the key sequence hint panel shows for one step (#1871 ▸
/// hint panel): one headline breadcrumb of the leader and each
/// branch taken (#3381), the keys that open more keys first, then
/// the end keys as the Shortcuts side files them. Core names the
/// path; this reads the stored tree it names.
struct KeySequenceHint: Equatable {
    /// One key the breadcrumb or the branch list draws: its chord,
    /// drawn, its name and the symbol it leads with (#3162).
    struct Key: Equatable, Identifiable {
        var chord: String
        var name: String
        var symbol = BranchMark.symbol
        var id: String { chord }

        /// What a crumb draws beside its symbol: its name, or its
        /// chord while it has none (#3381).
        var shown: String { name.isEmpty ? chord : name }
    }

    /// The leader, then each branch key pressed.
    var crumbs: [Key]
    /// This step's keys that open more keys, each drawn with ›.
    var branches: [Key]
    /// This step's end keys, as a layer the reference builder files.
    var endKeys: KeyLayer

    /// The hint for `progress` over the layer it ran in; nil where
    /// the stored tree no longer holds that path — a save between
    /// the press and the hop.
    @MainActor static func of(
        _ progress: KeySequenceProgress,
        in layer: KeyLayer
    ) -> KeySequenceHint? {
        guard
            var node = layer.sequences.first(where: {
                $0.combo == progress.leader
            })
        else { return nil }
        var crumbs = [crumb(node)]
        for step in progress.path {
            guard
                let next = node.steps?.first(where: {
                    $0.combo == step && $0.isSequence
                })
            else { return nil }
            crumbs.append(crumb(next))
            node = next
        }
        let keys = node.steps ?? []
        return KeySequenceHint(
            crumbs: crumbs,
            branches: keys.filter(\.isSequence).map(crumb),
            endKeys: KeyLayer(
                name: layer.name,
                bindings: keys.filter { !$0.isSequence }
            )
        )
    }

    /// A stored chord as the GUI draws it, its spelling where it
    /// does not parse.
    @MainActor static func drawn(_ stored: String) -> String {
        KeyCombo.parse(stored).map {
            ChordGlyphs.render($0, layoutChar: LayoutKeyGlyph.char)
        } ?? stored
    }

    /// A node as a crumb or a branch row: its chord, its name and
    /// the symbol the card's pill draws.
    @MainActor private static func crumb(_ node: KeyBinding) -> Key {
        Key(
            chord: drawn(node.combo),
            name: node.label,
            symbol: BranchMark.symbol(of: node)
        )
    }

    /// The headline's words: "Leader › Windows", a passed chord
    /// dropped unless its crumb has no name (#3381).
    var headline: String {
        crumbs.map(\.shown).joined(separator: " › ")
    }

    /// The headline as VoiceOver reads it, an unnamed crumb's chord
    /// in words.
    @MainActor var spokenHeadline: String {
        crumbs.map { key in
            key.name.isEmpty ? SidedChordWords.label(key.chord) : key.name
        }
        .joined(separator: ", ")
    }
}
