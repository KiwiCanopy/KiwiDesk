import KiwiDeskCore
import SwiftUI

/// Why an Advanced Colours row draws nothing right now, and where
/// the page says so (#1857, #1310): the ONE verdict the row's grey,
/// its card's links and the group well all read.
struct ColorRowVerdict: Equatable {
    /// Where the row's reason is drawn beneath its card.
    enum Link: Equatable {
        /// The card's shared link to the page whose switch dims it.
        case page(SettingsDestination)
        /// The row's own sentence, linking that page.
        case ownSentence(SettingsDestination)

        var destination: SettingsDestination {
            switch self {
            case .page(let d), .ownSentence(let d): return d
            }
        }
    }

    /// The hover reason on the dimmed row.
    let help: String
    let link: Link
}

extension AdvancedColorsGates {
    /// The verdict for one row; nil while it draws. The shelf's
    /// block gate outranks a row's own reason, so the outer switch
    /// is the one named (#527).
    func verdict(for key: SettingKey) -> ColorRowVerdict? {
        if !shelfDraws, Self.takesShelfGate(key) {
            return ColorRowVerdict(
                help: AdvancedColorsHelp.kiwishelfOff,
                link: .page(.bars)
            )
        }
        switch key {
        case .kiwishelf(.borderColor):
            return shelfBorderOff
                ? ColorRowVerdict(
                    help: AdvancedColorsHelp.shelfBorderOff,
                    link: .ownSentence(.bars)
                ) : nil
        case .spaceBar(.spaceBarFocusedItemColor):
            guard focusedItemInert else { return nil }
            return ColorRowVerdict(
                help: AdvancedColorsHelp.focusedItemHelp,
                link: .ownSentence(.bars)
            )
        case .spaceBar(.spaceBarFocusedHighlightColor):
            guard focusedHighlightInert else { return nil }
            return ColorRowVerdict(
                help: AdvancedColorsHelp.frontAppOff,
                link: .page(.bars)
            )
        case .borders(.borderFocusedColor):
            return borderOn ? nil : borderOffVerdict
        case .borders(.borderUnfocusedColor):
            if !borderOn { return borderOffVerdict }
            return unfocusedOn
                ? nil
                : ColorRowVerdict(
                    help: AdvancedColorsHelp.unfocusedOff,
                    link: .ownSentence(.gapsAndBorders)
                )
        case .borders(.dragGhostBorderColor):
            return dragVerdict(ghost: true, fill: false)
        case .borders(.dragGhostFillColor):
            return dragVerdict(ghost: true, fill: true)
        case .borders(.dragDropZoneBorderColor):
            return dragVerdict(ghost: false, fill: false)
        case .borders(.dragDropZoneFillColor):
            return dragVerdict(ghost: false, fill: true)
        default:
            return nil
        }
    }

    /// Whether the shelf's block gate reaches `key`: the bar rows,
    /// save one the census exempts from its container gate.
    nonisolated static func takesShelfGate(
        _ key: SettingKey
    ) -> Bool {
        guard !key.placement.exemptFromContainerGate else {
            return false
        }
        switch key {
        case .kiwishelf, .spaceBar: return true
        default: return false
        }
    }

    /// The pages a card links for its dimmed rows, in row order and
    /// once each — a page a row's own sentence already links is
    /// left out.
    func dimmedDestinations(
        of keys: [SettingKey]
    ) -> [SettingsDestination] {
        let links = keys.compactMap { verdict(for: $0)?.link }
        let own = links.compactMap { link -> SettingsDestination? in
            if case .ownSentence(let d) = link { return d }
            return nil
        }
        var out: [SettingsDestination] = []
        for case .page(let d) in links
        where !own.contains(d) && !out.contains(d) {
            out.append(d)
        }
        return out
    }

    /// Whether `key`'s own sentence draws beneath its card.
    func needsOwnSentence(_ key: SettingKey) -> Bool {
        if case .ownSentence = verdict(for: key)?.link { return true }
        return false
    }

    private var borderOffVerdict: ColorRowVerdict {
        ColorRowVerdict(
            help: AdvancedColorsHelp.borderOff,
            link: .page(.gapsAndBorders)
        )
    }

    private func dragVerdict(
        ghost: Bool,
        fill: Bool
    ) -> ColorRowVerdict? {
        dragInert(ghost: ghost, fill: fill)
            ? ColorRowVerdict(
                help: dragHelp(ghost: ghost, fill: fill),
                link: .page(.gapsAndBorders)
            ) : nil
    }
}
