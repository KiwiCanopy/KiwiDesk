import Foundation
import KiwiDeskCore

/// What the key sequence hint panel shows for one step (#1871 ▸
/// hint panel): the leader's name as its title, the steps taken as
/// a breadcrumb, the keys that open more keys first, then the end
/// keys as the Shortcuts side files them. Core names the path; this
/// reads the stored tree it names.
struct KeySequenceHint: Equatable {
    /// One key the breadcrumb or the branch list draws: its chord,
    /// drawn, its name and the symbol it leads with (#3162).
    struct Key: Equatable, Identifiable {
        var chord: String
        var name: String
        var symbol = BranchMark.symbol
        var id: String { chord }
    }

    var title: String
    /// The leader, then each step key pressed.
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
        var crumbs = [Key(chord: drawn(node.combo), name: node.label)]
        for step in progress.path {
            guard
                let next = node.steps?.first(where: {
                    $0.combo == step && $0.isSequence
                })
            else { return nil }
            crumbs.append(Key(chord: drawn(next.combo), name: next.label))
            node = next
        }
        let keys = node.steps ?? []
        return KeySequenceHint(
            title: crumbs[0].name.isEmpty ? crumbs[0].chord : crumbs[0].name,
            crumbs: crumbs,
            branches: keys.filter(\.isSequence).map {
                Key(
                    chord: drawn($0.combo),
                    name: $0.label,
                    symbol: $0.meta.usableSymbol ?? BranchMark.symbol
                )
            },
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

    /// The breadcrumb as one line: "⌃⌥Space › W Windows".
    var breadcrumb: String {
        crumbs.enumerated().map { index, key in
            index == 0 || key.name.isEmpty
                ? key.chord : key.chord + " " + key.name
        }
        .joined(separator: " › ")
    }

    /// The breadcrumb as VoiceOver reads it, each chord in words.
    @MainActor var spokenBreadcrumb: String {
        crumbs.map { key in
            let chord = SidedChordWords.label(key.chord)
            return key.name.isEmpty ? chord : chord + " " + key.name
        }
        .joined(separator: ", ")
    }
}
