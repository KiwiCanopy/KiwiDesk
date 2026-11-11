import KiwiDeskCore
import SwiftUI

/// The Mouse & Trackpad part's entries in page order (#1726,
/// #3184): each one's sentence, picture, surface and pace, read by
/// its entry alone.
enum GestureItem: String, CaseIterable, Identifiable {
    case hoverFocus, followFocus
    case swap, edge
    case scrollStep, spaceStep
    case dropOnSpace, spring, glyphClick, glyphPeek, shelfScroll
    case contextMenu, appBarReorder, appBarHover

    /// Where the hand is: the part's groups.
    enum Group: CaseIterable {
        case windows, modifier, shelf
    }

    var id: String { rawValue }

    /// The entry's reveal anchor.
    var anchor: String { "shortcuts.gestures.entry.\(rawValue)" }

    var group: Group {
        switch self {
        case .scrollStep, .spaceStep: return .modifier
        case .hoverFocus, .followFocus, .swap, .edge: return .windows
        default: return .shelf
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
    func isOff(_ gestures: ScrollGestureBase) -> Bool {
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
