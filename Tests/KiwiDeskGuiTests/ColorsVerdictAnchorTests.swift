import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every dimmed Advanced Colours row is explained by a live link,
/// in every combination of the switches that dim them (#1857,
/// #1310). The verdict is the one answer the grey, the links and
/// the group well read, so this walks it rather than a hand-picked
/// state: a row that greys with no anchor, or a census gate the
/// verdict never answers, reds here.
///
/// `@MainActor` for the verdict's sentences; the walk is 2¹³
/// settings values over 19 rows, pure value work (~1 s).
@MainActor
@Suite("Advanced Colours verdict anchors")
struct ColorsVerdictAnchorTests {
    /// A card, the rows whose own sentence it draws, and whether
    /// it draws the page links (the KiwiShelf card answers its
    /// block gate on the header `?` instead).
    private struct Card {
        let keys: [SettingKey]
        let ownSentences: Set<SettingKey>
        let drawsPageLinks: Bool
    }

    private let cards = [
        Card(
            keys: ColorRole.accent.keys,
            ownSentences: [],
            drawsPageLinks: true
        ),
        Card(
            keys: ColorRole.secondAccent.keys,
            ownSentences: [.spaceBar(.spaceBarFocusedItemColor)],
            drawsPageLinks: true
        ),
        Card(
            keys: ColorsRowOrder.kiwishelfAtRest,
            ownSentences: [.kiwishelf(.borderColor)],
            drawsPageLinks: false
        ),
        Card(
            keys: ColorsRowOrder.windowMarksAtRest,
            ownSentences: [.borders(.borderUnfocusedColor)],
            drawsPageLinks: true
        ),
    ]

    /// Every combination of the switches the area's gates read.
    private func states() -> [TilingSettings] {
        let flags: [WritableKeyPath<TilingSettings, Bool>] = [
            \.spaceBarStyle.enabled,
            \.monocle.appBar.enabled,
            \.spaceBarStyle.showFrontApp,
            \.kiwishelf.border,
            \.borderStyle.enabled,
            \.borderStyle.unfocusedEnabled,
            \.dragGhost.enabled,
            \.dragGhost.border,
            \.dragGhost.fill,
            \.dragDropZone.enabled,
            \.dragDropZone.border,
            \.dragDropZone.fill,
        ]
        var out: [TilingSettings] = []
        for mask in 0..<(1 << (flags.count + 1)) {
            var settings = TilingSettings()
            settings.scrolling.appBar.enabled = false
            for (bit, flag) in flags.enumerated() {
                settings[keyPath: flag] = mask & (1 << bit) != 0
            }
            settings.kiwishelf.iconSource =
                mask & (1 << flags.count) != 0 ? .appFont : .appImage
            out.append(settings)
        }
        return out
    }

    @Test("every dimmed row is explained beneath its card")
    func everyDimmedRowIsAnchored() {
        let all = states()
        #expect(all.count == 8192)
        var dimmed = 0
        for settings in all {
            let gates = AdvancedColorsGates(settings: settings)
            for card in cards {
                let pages = gates.dimmedDestinations(of: card.keys)
                for key in card.keys {
                    guard let verdict = gates.verdict(for: key) else {
                        continue
                    }
                    dimmed += 1
                    switch verdict.link {
                    case .ownSentence(let destination):
                        #expect(
                            card.ownSentences.contains(key),
                            "\(key.id) has no sentence in its card"
                        )
                        #expect(!pages.contains(destination))
                    case .page(let destination):
                        if card.drawsPageLinks {
                            let own = card.keys.contains {
                                gates.verdict(for: $0)?.link
                                    == .ownSentence(destination)
                            }
                            #expect(
                                pages.contains(destination) || own,
                                "\(key.id): no link to \(destination)"
                            )
                        } else {
                            // The header `?` answers it: only the
                            // block gate may reach this card.
                            #expect(!gates.shelfDraws, "\(key.id)")
                        }
                    }
                }
            }
        }
        // Vacuity: the walk dims rows at all.
        #expect(dimmed > 10_000)
    }

    /// The census half: a row the census gates is dimmed by the
    /// verdict in some state, and a row it leaves ungated never
    /// is — so a gate added to the census without a verdict, or
    /// a verdict greying an ungated row, reds.
    @Test("the verdict answers exactly the census-gated rows")
    func verdictMatchesTheCensus() {
        let keys = SettingKey.allCases.filter {
            $0.placement.area == .advancedColours
                && !ColorRole.paintKeys.contains($0)
        }
        #expect(keys.count == 19)
        let all = states()
        for key in keys {
            let ever = all.contains {
                AdvancedColorsGates(settings: $0).verdict(for: key)
                    != nil
            }
            #expect(
                ever == (key.placement.gate != nil),
                "\(key.id): census gate and verdict disagree"
            )
        }
    }
}
