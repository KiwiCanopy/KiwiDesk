import AppKit
import KiwiDeskCore
import SwiftUI

/// The Spaces-list reorder (#68): an axis-locked handle drag,
/// deliberately *not* a system drag session — a session's
/// ghost follows the pointer on both axes and cannot be
/// constrained, while here the row itself steps slot to slot
/// and never leaves the column.
extension SpacesSection {
    /// The rows to render: the live drag order while a drag is in
    /// flight, otherwise the model's own order (#299).
    var displayedSpaces: [SpaceID] {
        dragOrder ?? model.config.spaces
    }

    /// The open-hand cursor on hover is the drag affordance
    /// the handle glyph alone doesn't deliver. Cursor changes
    /// use `set()` rather than push/pop: the pointer leaves
    /// the 20×24 handle almost immediately during a drag, so
    /// hover enter/exit and drag start/end interleave in ways
    /// a stack cannot balance (a mid-drag exit would pop the
    /// closed hand; a re-enter would push an extra open hand
    /// that outlives the drag). While a drag is live, hover
    /// stops driving the cursor; `hoveredHandle` keeps the
    /// drag-start handle (mid-drag hover events rarely arrive
    /// at all), which stays truthful because retargeting
    /// keeps the row under the pointer — drag end reads it.
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
                // A row removed under the pointer (context-
                // menu delete) never delivers the balancing
                // onHover(false), and a cancelled drag (the
                // window resigning key) skips onEnded — drop
                // the stale state and restore whichever
                // cursor the remaining hover state earns.
                guard
                    hoveredHandle == space || dragged == space
                else { return }
                if hoveredHandle == space {
                    hoveredHandle = nil
                }
                if dragged == space {
                    // A cancelled drag skips onEnded — flush the
                    // in-flight order so the reorder isn't lost
                    // and dragOrder can't linger stale.
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
                // Snapshot the model into the live drag order
                // so every crossing reorders a local array,
                // not the @Published/profile-backed one.
                dragOrder = model.config.spaces
                NSCursor.closedHand.set()
            }
            retarget(space, at: value.location.y)
        }
        .onEnded { _ in
            // The pointer usually still sits on a handle
            // after the drop, and hover won't refire without
            // an exit/enter — restore the affordance the
            // tracked hover state says is truthful.
            (hoveredHandle != nil
                ? NSCursor.openHand : .arrow)
                .set()
            commitDragOrder()
            withAnimation(Self.reorderSpring) {
                dragged = nil
            }
        }
    }

    /// Only the pointer's *vertical* position matters, and a
    /// swap fires only once the pointer crosses the candidate
    /// row's MIDPOINT — plain band containment oscillates
    /// with variable-height rows (after a short row moves
    /// past a tall one, the pointer can still sit inside the
    /// tall row's new band and the next movement swaps them
    /// straight back).
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
        withAnimation(Self.reorderSpring) {
            order.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
            dragOrder = order
        }
    }

    /// One light spring for both the per-swap shuffle and the
    /// drop settle — replaces the old stacked `easeInOut(0.15)`
    /// per swap plus a separate drop spring, whose compounding
    /// read as sluggish on a fast multi-row drag (#299).
    static let reorderSpring: Animation = .interactiveSpring(
        response: 0.25,
        dampingFraction: 0.86
    )

    /// Flush the live drag order into the model exactly once, at
    /// the end of a drag (or if the row tears down mid-drag). No-op
    /// when nothing moved, so a plain click never dirties the
    /// profile. Clearing `dragOrder` hands rendering back to the
    /// model — identical order, so no visual jump.
    func commitDragOrder() {
        if let order = dragOrder, order != model.config.spaces {
            model.config.spaces = order
        }
        dragOrder = nil
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
