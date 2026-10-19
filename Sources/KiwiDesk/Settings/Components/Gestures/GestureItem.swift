import KiwiDeskCore
import SwiftUI

/// The Mouse & trackpad card's entries in card order (#1726): each
/// one's sentence, picture, surface and pace, read by its entry
/// and by the shut card's picture strip alike, so the two can
/// never show a gesture differently.
enum GestureItem: String, CaseIterable, Identifiable {
    case scrollStep, spaceStep
    case hoverFocus, followFocus
    case swap, edge
    case dropOnSpace, spring, glyphClick, glyphPeek, shelfScroll
    case contextMenu, appBarReorder, appBarHover

    /// Where the hand is: the card's four headings.
    enum Group: CaseIterable {
        case scroll, focus, windows, shelf
    }

    var id: String { rawValue }

    /// The entry's reveal anchor, which a strip click lands on.
    var anchor: String { "shortcuts.gestures.entry.\(rawValue)" }

    var group: Group {
        switch self {
        case .scrollStep, .spaceStep: return .scroll
        case .hoverFocus, .followFocus: return .focus
        case .swap, .edge: return .windows
        default: return .shelf
        }
    }

    var surface: GestureSurface {
        switch self {
        case .scrollStep, .spaceStep, .hoverFocus, .followFocus,
            .swap, .edge:
            return .windows
        case .dropOnSpace, .spring, .glyphClick, .glyphPeek:
            return .spaceBar
        case .shelfScroll, .contextMenu: return .shelf
        case .appBarReorder, .appBarHover: return .appBar
        }
    }

    var pace: GesturePace {
        switch self {
        case .edge, .shelfScroll: return .quick
        case .spaceStep, .swap, .dropOnSpace, .spring: return .story
        default: return .steps
        }
    }

    /// Whether the gesture does nothing on this draft: its chord is
    /// cleared (Core's verdict, so a hand-edited lone ⌃ greys too).
    func isOff(_ settings: TilingSettings, _ gestures: ScrollGestureBase)
        -> Bool
    {
        switch self {
        case .scrollStep: return gestures.sanitized.pan.isEmpty
        case .spaceStep: return gestures.sanitized.spaceStep.isEmpty
        default: return false
        }
    }

    @MainActor @ViewBuilder
    func picture(t: CGFloat, gestures: ScrollGestureBase) -> some View {
        switch self {
        case .scrollStep:
            GesturePicture.ScrollStep(t: t, chord: gestures.pan)
        case .spaceStep:
            GesturePicture.SpaceStep(t: t, chord: gestures.spaceStep)
        case .hoverFocus: GesturePicture.HoverFocus(t: t)
        case .followFocus: GesturePicture.FollowFocus(t: t)
        case .swap: GesturePicture.Swap(t: t)
        case .edge: GesturePicture.Edge(t: t)
        case .dropOnSpace: GesturePicture.DropOnSpace(t: t)
        case .spring: GesturePicture.Spring(t: t)
        case .glyphClick: GesturePicture.GlyphClick(t: t)
        case .glyphPeek: GesturePicture.GlyphPeek(t: t)
        case .shelfScroll: GesturePicture.ShelfScroll(t: t)
        case .contextMenu: GesturePicture.ContextMenu(t: t)
        case .appBarReorder: GesturePicture.AppBarReorder(t: t)
        case .appBarHover: GesturePicture.AppBarHover(t: t)
        }
    }
}
