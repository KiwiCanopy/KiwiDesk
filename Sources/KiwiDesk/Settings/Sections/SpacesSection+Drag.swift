import AppKit
import KiwiDeskCore
import SwiftUI

/// The Spaces-list reorder (#68): an axis-locked handle drag,
/// deliberately *not* a system drag session — a session's
/// ghost follows the pointer on both axes and cannot be
/// constrained, while here the row itself steps slot to slot
/// and never leaves the column.
extension SpacesSection {
    /// The open-hand cursor on hover is the drag affordance
    /// the handle glyph alone doesn't deliver.
    func dragHandle(_ space: SpaceID) -> some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 24)
            .contentShape(Rectangle())
            .help("Drag to reorder")
            .onHover { inside in
                if inside {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(dragGesture(space))
    }

    private func dragGesture(
        _ space: SpaceID
    ) -> some Gesture {
        DragGesture(
            coordinateSpace: .named(Self.listSpace)
        )
        .onChanged { value in
            if dragged == nil {
                dragged = space
                NSCursor.closedHand.push()
            }
            retarget(space, at: value.location.y)
        }
        .onEnded { _ in
            NSCursor.pop()
            withAnimation(
                .spring(response: 0.35, dampingFraction: 0.7)
            ) {
                dragged = nil
            }
        }
    }

    /// Only the pointer's *vertical* position matters: when it
    /// crosses into another row's band, the dragged space
    /// moves to that slot (the same before/after rule the
    /// context menu's Move Up/Down applies).
    private func retarget(_ space: SpaceID, at y: CGFloat) {
        guard
            let target = rowFrames.first(where: {
                $0.key != space
                    && $0.value.minY <= y
                    && y <= $0.value.maxY
            })?.key,
            let from = model.config.spaces.firstIndex(
                of: space
            ),
            let to = model.config.spaces.firstIndex(
                of: target
            ),
            from != to
        else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            model.config.spaces.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
    }

    /// Row frames in list space, keyed by space — the drag
    /// gesture's retarget lookup.
    struct SpaceRowFrames: PreferenceKey {
        static var defaultValue: [SpaceID: CGRect] { [:] }
        static func reduce(
            value: inout [SpaceID: CGRect],
            nextValue: () -> [SpaceID: CGRect]
        ) {
            value.merge(nextValue()) { _, new in new }
        }
    }
}
