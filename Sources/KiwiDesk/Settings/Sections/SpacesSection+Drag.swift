import AppKit
import KiwiDeskCore
import SwiftUI

/// Spaces list reordering drag gesture logic (#68).
extension SpacesSection {
    /// Ordered space list for rendering during drag (#299).
    var displayedSpaces: [SpaceID] {
        dragOrder ?? model.config.spaces
    }

    /// Reorder drag handle view with hover cursor affordance.
    func dragHandle(_ space: SpaceID) -> some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 24)
            .contentShape(Rectangle())
            .help(
                L("spaces.drag_handle.help", "Drag to reorder")
            )
            .onHover { inside in
                hoveredHandle =
                    inside
                    ? space
                    : (hoveredHandle == space
                        ? nil : hoveredHandle)
                guard dragged == nil else { return }
                (inside ? NSCursor.openHand : .arrow).set()
            }
            .onDisappear {
                guard
                    hoveredHandle == space || dragged == space
                else { return }
                if hoveredHandle == space {
                    hoveredHandle = nil
                }
                if dragged == space {
                    commitDragOrder()
                    dragged = nil
                }
                (hoveredHandle != nil
                    ? NSCursor.openHand : .arrow)
                    .set()
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
                dragOrder = model.config.spaces
                NSCursor.closedHand.set()
            }
            retarget(space, at: value.location.y)
        }
        .onEnded { _ in
            (hoveredHandle != nil
                ? NSCursor.openHand : .arrow)
                .set()
            commitDragOrder()
            withAnimation(reorderAnimation) {
                dragged = nil
            }
        }
    }

    /// Evaluates vertical pointer crossing against candidate row midpoint.
    private func retarget(_ space: SpaceID, at y: CGFloat) {
        var order = dragOrder ?? model.config.spaces
        guard
            let candidate = rowFrames.first(where: {
                $0.key != space
                    && $0.value.minY <= y
                    && y <= $0.value.maxY
            }),
            let from = order.firstIndex(of: space),
            let to = order.firstIndex(of: candidate.key),
            from != to,
            to > from
                ? y >= candidate.value.midY
                : y <= candidate.value.midY
        else { return }
        withAnimation(reorderAnimation) {
            order.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
            dragOrder = order
        }
    }

    /// Reorder transition spring animation (#299).
    static let reorderSpring: Animation = .interactiveSpring(
        response: 0.25,
        dampingFraction: 0.86
    )

    /// Animation respecting system Reduce Motion setting.
    var reorderAnimation: Animation? {
        reduceMotion ? nil : Self.reorderSpring
    }

    /// Commits in-flight reorder to configuration model.
    func commitDragOrder() {
        if let order = dragOrder, order != model.config.spaces {
            model.config.spaces = order
        }
        dragOrder = nil
    }

    /// List coordinate frames preference key.
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
