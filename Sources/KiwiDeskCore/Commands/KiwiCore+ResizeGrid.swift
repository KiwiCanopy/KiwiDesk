import AppKit
import Foundation

/// Grid-mode `resize` (#763): a column or row is resized by
/// moving the edge it shares with a neighbour, every other track
/// keeping the length it drew — the bsp arm's shared-edge shape
/// over per-index track weights (`GridTracks`). The
/// keyboard verb and the mouse drop both take
/// `resizeGridMember`, so the two cannot clamp or cue apart.
extension KiwiCore {
    /// Which of a cell's edges a gesture moved: the mouse knows,
    /// the keyboard grows the focused cell at its trailing edge
    /// and at its leading one where it reaches the far side.
    enum GridEdge {
        case leading
        case trailing
    }

    func resizeGrid(
        axis: String,
        delta: Double,
        space: Space
    ) -> CommandResponse {
        // `space.focused`, like every other resize path (#308).
        guard let focused = space.focused else {
            return .fail("no focused tiled window")
        }
        return resizeGridMember(
            focused,
            axis: axis,
            delta: delta,
            edge: nil,
            space: space
        )
    }

    /// Grows `window`'s cell by `delta` points along `axis` —
    /// "x" its columns, "y" its rows — writing the session layer
    /// (#764) so `reset_layout_sizing` returns to the authored
    /// weights.
    @discardableResult
    func resizeGridMember(
        _ window: WindowID,
        axis: String,
        delta: Double,
        edge: GridEdge?,
        space: Space
    ) -> CommandResponse {
        guard
            let screen = TilingEngine.screen(
                for: space.id,
                in: state
            )
        else { return .fail("no screen to lay the space out on") }
        let input = tiler.layoutInput(
            state: state,
            space: space,
            screen: screen
        )
        let context = input.context
        let tiled = input.tiled
        guard tiled.contains(window) else {
            return .fail("no focused tiled window")
        }
        // Equal cells under the floor cascade the whole Space:
        // the grid draws no tracks to divide.
        guard
            let shape = GridLayout.shape(
                count: tiled.count,
                in: context
            )
        else {
            refuseNothingToDivide(window, otherAxisDivides: false)
            return .fail("the grid is a single pile")
        }
        let cells = GridLayout.cellIndices(
            of: tiled,
            shape: shape,
            in: context
        )
        guard let index = cells[window] else {
            return .fail("no focused tiled window")
        }
        let horizontal = axis == "x"
        // A run that lays its members by floor and weight, not by
        // column, takes a press along it as a run weight (#2541).
        if shape.scrolls, horizontal == shape.rowMajor,
            index >= GridLayout.runStart(of: shape),
            GridLayout.zones(for: tiled, in: context)?.first?
                .drawsSlots(in: context) == false,
            let response = resizeInRun(
                window,
                axis: axis,
                delta: delta,
                space: space,
                otherAxisDivides: true
            )
        {
            return response
        }
        let cell = GridLayout.cell(index, of: shape)
        let span = horizontal ? cell.columns : cell.rows
        let across = horizontal ? cell.rows : cell.columns
        let count = horizontal ? shape.columns : shape.rows
        let otherCount = horizontal ? shape.rows : shape.columns
        guard
            let (grown, neighbor) = Self.gridEdgePair(
                span: span,
                count: count,
                edge: edge
            )
        else {
            // The cell reaches both outer edges on this axis —
            // one track, or the short last row spanning it.
            refuseNothingToDivide(
                window,
                otherAxisDivides: across.first > 0
                    || across.last < otherCount - 1
            )
            return .fail("the cell spans the grid on this axis")
        }
        let floors = GridLayout.trackFloors(
            windows: tiled,
            shape: shape,
            horizontal: horizontal,
            context: context
        )
        let grownMembers = members(
            ofTrack: grown,
            horizontal: horizontal,
            ordered: tiled,
            cells: cells,
            shape: shape
        )
        let neighborMembers = members(
            ofTrack: neighbor,
            horizontal: horizontal,
            ordered: tiled,
            cells: cells,
            shape: shape
        )
        // The context carries the session layer over the
        // authored weights (`resolvedGrid(for: Space)`).
        let stored =
            horizontal
            ? context.grid.columnWeights : context.grid.rowWeights
        // A pair that cannot hold both floors is drawn by the
        // render's floor fallback; the write stands still.
        let step = GridTracks.moveEdge(
            weights: stored,
            grown: grown,
            neighbor: neighbor,
            floors: floors.map(\.size),
            delta: CGFloat(delta)
        ) {
            GridLayout.axisLengths(
                weights: $0,
                floors: floors,
                horizontal: horizontal,
                context: context
            )
        }
        if let step {
            writeGridWeights(step.weights, axis: axis, for: space.id)
        }
        guard step?.clamped ?? true, delta != 0 else { return .ok() }
        // A shrink runs into the resized track's own floor, a grow
        // into the neighbour's.
        if delta < 0 {
            reportResizeRefusal(
                focused: window,
                bindingCarrier: shown(floors[grown].carrier, cells),
                fallbackAnchor: grownMembers.first {
                    $0 != window
                },
                // A cell spanning several tracks is no member of
                // the one whose floor bound (#1259).
                focusedIsBinding: span.first == span.last,
                axis: axis
            )
        } else {
            reportResizeRefusal(
                focused: window,
                bindingCarrier: shown(floors[neighbor].carrier, cells),
                fallbackAnchor: neighborMembers.first,
                focusedIsBinding: false,
                axis: axis
            )
        }
        return .ok()
    }

    /// The track the gesture grows and the neighbour it trades
    /// with, or nil where the cell has no inner edge on the axis.
    static func gridEdgePair(
        span: GridTracks.Span,
        count: Int,
        edge: GridEdge?
    ) -> (grown: Int, neighbor: Int)? {
        let trailing =
            span.last + 1 < count ? (span.last, span.last + 1) : nil
        let leading =
            span.first > 0 ? (span.first, span.first - 1) : nil
        switch edge {
        case .leading: return leading
        case .trailing: return trailing
        case nil: return trailing ?? leading
        }
    }

    /// `carrier` where it is drawn: a run member waiting off screen
    /// lifts the last track (#2541) but takes no pill.
    private func shown(
        _ carrier: WindowID?,
        _ cells: [WindowID: Int]
    ) -> WindowID? {
        carrier.flatMap { cells[$0] == nil ? nil : $0 }
    }

    /// The shown windows whose cell lies in `track` alone on the
    /// axis — a refusal's anchor.
    private func members(
        ofTrack track: Int,
        horizontal: Bool,
        ordered: [WindowID],
        cells: [WindowID: Int],
        shape: GridLayout.Shape
    ) -> [WindowID] {
        ordered.compactMap { window in
            guard let index = cells[window] else { return nil }
            let cell = GridLayout.cell(index, of: shape)
            let span = horizontal ? cell.columns : cell.rows
            return span.first == track && span.last == track
                ? window : nil
        }
    }
}
