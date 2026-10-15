import KiwiDeskCore

/// The Hyper move offer's model half (#1870): which direction is
/// offered, the sheet's lines named from the draft, and the move
/// staged into the draft like any recorded chord — Save registers
/// it (input-and-animation.md ▸ written only from saved files).
extension SettingsModel {
    /// The direction on offer: to Hyper while a key is set, back
    /// while none is.
    var hyperMoveDirection: HyperShortcutMove.Direction {
        appWide.hyperKey == nil ? .back : .toHyper
    }

    /// What the offer would move, read off the default layer — the
    /// one the seed authors. Nil where it would move nothing, so the
    /// offer retires once accepted.
    var hyperMoveOffer: HyperShortcutMove.Offer? {
        guard let layer = config.layers.first(where: \.isDefault) else {
            return nil
        }
        let offer = HyperShortcutMove.offer(
            hyperMoveDirection,
            rows: layer.bindings,
            base: config.desktopShortcutBase
        )
        return offer.isEmpty ? nil : offer
    }

    /// Whether the draft holds anything on Hyper — a row or the
    /// Desktop base — which keeps the Hyper card in Simple with no
    /// key set, since config presence expands Simple (gui.md).
    var draftUsesHyper: Bool {
        config.desktopShortcutBase == .hyper
            || config.layers.contains {
                $0.bindings.contains {
                    KeyCombo.parse($0.combo)?.modifiers.contains(.hyper)
                        == true
                }
            }
    }

    /// The sheet for the offer on screen.
    func hyperMoveRequest() -> HyperMoveRequest? {
        guard let offer = hyperMoveOffer else { return nil }
        return HyperMoveRequest(
            direction: hyperMoveDirection,
            lines: offer.items.map(line(for:)),
            desktop: offer.desktop.map(desktopLine(for:))
        )
    }

    /// Stages the picked lines into the draft.
    func applyHyperMove(
        _ direction: HyperShortcutMove.Direction,
        items: Set<String>,
        desktop: Bool
    ) {
        HyperShortcutMove.apply(
            direction,
            items: items,
            desktop: desktop,
            to: &config
        )
    }

    private func line(for item: HyperShortcutMove.Item) -> HyperMoveLine {
        let names = item.seeds.map {
            KeybindingCatalog.localizedName(of: $0, config: config)
        }
        let name =
            item.seeds.count > 1
            ? HyperMoveWords.kiwiHub(settings: names.last ?? "")
            : names.first ?? item.id
        let refusal = item.taken.map { holder in
            HyperMoveWords.taken(
                chord: HyperMoveWords.chord(
                    item.moves.first?.to ?? holder.combo
                ),
                by: KeybindingCatalog.localizedName(
                    of: holder,
                    config: config
                )
            )
        }
        return HyperMoveLine(
            id: item.id,
            name: name,
            chords: HyperMoveWords.chords(item.moves),
            ticked: item.seeded && item.taken == nil,
            refusal: refusal
        )
    }

    private func desktopLine(
        for line: HyperShortcutMove.DesktopLine
    ) -> HyperMoveLine {
        let kept = line.kept.map {
            HyperMoveWords.taken(
                chord: HyperMoveWords.chord($0.move.to),
                by: KeybindingCatalog.localizedName(
                    of: $0.holder,
                    config: config
                )
            )
        }
        return HyperMoveLine(
            id: HyperMoveLine.desktopID,
            name: HyperMoveWords.desktop(
                from: HyperMoveWords.modifiers(line.from),
                to: HyperMoveWords.modifiers(line.base)
            ),
            chords: "",
            ticked: true,
            refusal: nil,
            notes: kept
        )
    }
}
