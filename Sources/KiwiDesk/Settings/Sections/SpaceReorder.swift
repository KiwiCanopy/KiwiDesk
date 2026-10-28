import AppKit
import Combine
import KiwiDeskCore
import SwiftUI

/// A Space list's drag-to-reorder (#68, #299): the Spaces page and
/// Simple's rows (#2737) share it. The live order during a drag is
/// written back once on drop — a per-crossing profile write
/// re-evaluated the whole config (#299).
@MainActor
final class SpaceReorder: ObservableObject {
    @Published var dragged: SpaceID?
    /// Live display order during a drag; nil when idle.
    @Published var dragOrder: [SpaceID]?
    @Published var hoveredHandle: SpaceID?
    /// Each row's frame in the list's coordinate space.
    var rowFrames: [SpaceID: CGRect] = [:]
    /// The list's named coordinate space.
    let listSpace: String

    init(listSpace: String) {
        self.listSpace = listSpace
    }

    /// Ordered list for rendering during a drag.
    func displayed(_ spaces: [SpaceID]) -> [SpaceID] {
        dragOrder ?? spaces
    }

    /// Commits the in-flight reorder, exactly once per drag. No-op
    /// when nothing moved, so a plain click never dirties the
    /// profile.
    func commit(to model: SettingsModel) {
        if let order = dragOrder, order != model.config.spaces {
            model.config.spaces = order
        }
        dragOrder = nil
    }

    /// Deactivating mid-drag abandons the gesture with no onEnded —
    /// commit so the list cannot keep showing an unsaved reorder.
    func abandon(to model: SettingsModel) {
        guard dragged != nil else { return }
        commit(to: model)
        dragged = nil
    }

    /// Swaps only once the pointer crosses the candidate row's
    /// MIDPOINT — plain band containment oscillates with
    /// variable-height rows: after a short row passes a tall one,
    /// the pointer can still sit inside the tall row's new band
    /// and the next movement swaps them straight back.
    func retarget(
        _ space: SpaceID,
        at y: CGFloat,
        in spaces: [SpaceID],
        animation: Animation?
    ) {
        var order = dragOrder ?? spaces
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
        withAnimation(animation) {
            order.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
            dragOrder = order
        }
    }

    /// Reorder transition spring animation (#299).
    static let spring: Animation = .interactiveSpring(
        response: 0.25,
        dampingFraction: 0.86
    )

    /// The spring, or nothing under Reduce Motion — ONE decision
    /// for both the per-swap shuffle and the drop settle: a
    /// reorder that springs at one and snaps at the other reads as
    /// a stutter. Rows still move; they arrive rather than travel.
    static func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : spring
    }

    /// List coordinate frames preference key.
    struct RowFrames: PreferenceKey {
        static var defaultValue: [SpaceID: CGRect] { [:] }
        static func reduce(
            value: inout [SpaceID: CGRect],
            nextValue: () -> [SpaceID: CGRect]
        ) {
            value.merge(nextValue()) { _, new in new }
        }
    }
}

/// A Space row's drag handle (#68). Cursor changes use `set()`,
/// never push/pop (gui.md): hover enter/exit and drag start/end
/// interleave in ways a stack cannot balance — a mid-drag exit
/// would pop the closed hand. While a drag is live, hover stops
/// driving the cursor; `hoveredHandle` keeps the drag-start handle,
/// which stays truthful because retargeting keeps the row under the
/// pointer.
struct SpaceDragHandle: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var reorder: SpaceReorder
    let space: SpaceID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 24)
            .contentShape(Rectangle())
            .help(L("spaces.drag_handle.help", "Drag to reorder"))
            .accessibilityHidden(true)
            .onHover { inside in
                reorder.hoveredHandle =
                    inside
                    ? space
                    : (reorder.hoveredHandle == space
                        ? nil : reorder.hoveredHandle)
                guard reorder.dragged == nil else { return }
                (inside ? NSCursor.openHand : .arrow).set()
            }
            .onDisappear {
                // A row removed under the pointer never delivers
                // the balancing onHover(false), and a cancelled
                // drag (window resigning key) skips onEnded — drop
                // the stale state, restore the earned cursor, and
                // flush the in-flight order.
                guard
                    reorder.hoveredHandle == space
                        || reorder.dragged == space
                else { return }
                if reorder.hoveredHandle == space {
                    reorder.hoveredHandle = nil
                }
                if reorder.dragged == space {
                    reorder.commit(to: model)
                    reorder.dragged = nil
                }
                (reorder.hoveredHandle != nil
                    ? NSCursor.openHand : .arrow)
                    .set()
            }
            .gesture(gesture)
    }

    private var animation: Animation? {
        SpaceReorder.animation(reduceMotion: reduceMotion)
    }

    private var gesture: some Gesture {
        DragGesture(coordinateSpace: .named(reorder.listSpace))
            .onChanged { value in
                if reorder.dragged == nil {
                    reorder.dragged = space
                    reorder.dragOrder = model.config.spaces
                    NSCursor.closedHand.set()
                }
                reorder.retarget(
                    space,
                    at: value.location.y,
                    in: model.config.spaces,
                    animation: animation
                )
            }
            .onEnded { _ in
                (reorder.hoveredHandle != nil
                    ? NSCursor.openHand : .arrow)
                    .set()
                reorder.commit(to: model)
                withAnimation(animation) {
                    reorder.dragged = nil
                }
            }
    }
}

extension View {
    /// Reports a Space row's frame to its list's reorder.
    func spaceRowFrame(
        _ space: SpaceID,
        in reorder: SpaceReorder
    ) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SpaceReorder.RowFrames.self,
                    value: [
                        space: proxy.frame(
                            in: .named(reorder.listSpace)
                        )
                    ]
                )
            }
        )
    }

    /// A row lifted while it is dragged, and measured for the
    /// retarget.
    func spaceDragLift(
        _ space: SpaceID,
        in reorder: SpaceReorder
    ) -> some View {
        let lifted = reorder.dragged == space
        return
            self
            .scaleEffect(lifted ? 1.02 : 1)
            .shadow(color: .black.opacity(lifted ? 0.2 : 0), radius: 6, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        lifted ? SettingsTheme.planeRing : .clear,
                        lineWidth: 1
                    )
            )
            .zIndex(lifted ? 1 : 0)
            .spaceRowFrame(space, in: reorder)
    }

    /// The list a reorder measures its rows in.
    func spaceReorderList(_ reorder: SpaceReorder) -> some View {
        coordinateSpace(name: reorder.listSpace)
            .onPreferenceChange(SpaceReorder.RowFrames.self) {
                reorder.rowFrames = $0
            }
    }
}
