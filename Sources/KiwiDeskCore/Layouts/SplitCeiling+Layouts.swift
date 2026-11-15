import CoreGraphics

/// Where each split layout's containers are for the ceiling pass
/// (#3217): Stack's two columns and the windows in each, BSP's
/// two sides per split, Grid's columns and rows. Each answers nil
/// where it draws a run or a pile, or where no span moves, which
/// keeps its frames.
extension SplitCeiling {
    /// Stack: the master and stack columns share across the
    /// split, then each column's windows along it.
    static func stack(
        _ windows: [WindowID],
        frames: [WindowID: CGRect],
        _ context: LayoutContext
    ) -> [WindowID: CGRect]? {
        guard var zones = StackLayout.zones(for: windows, in: context),
            laysFlat(zones, context)
        else { return nil }
        var moved = false
        if zones.count == 2 {
            let horizontal = context.stack.stackPosition.splitsHorizontally
            let ordered = zones.sorted {
                lead($0.region, horizontal) < lead($1.region, horizontal)
            }
            let spans = ordered.map { span($0.region, horizontal) }
            let shared = share(
                spans,
                ceilings: ordered.map {
                    zoneCeiling($0, horizontal: horizontal, context)
                }
            )
            if shared != spans {
                moved = true
                let regions = relaid(
                    ordered.map(\.region),
                    spans: shared,
                    horizontal: horizontal
                )
                zones = zip(ordered, regions).map { zone, region in
                    RunZone(
                        members: zone.members,
                        region: region,
                        vertical: zone.vertical,
                        ordinal: zone.ordinal
                    )
                }
                guard laysFlat(zones, context) else { return nil }
            }
        }
        var result = frames
        for zone in zones {
            if let laid = column(zone, moved: moved, context) {
                moved = true
                result.merge(laid) { _, new in new }
            }
        }
        return moved ? result : nil
    }

    /// Whether every zone lays its members at their shares — no
    /// run scrolls and none piles.
    private static func laysFlat(
        _ zones: [RunZone],
        _ context: LayoutContext
    ) -> Bool {
        zones.allSatisfy {
            $0.run(in: context) == nil && !$0.piles(in: context)
        }
    }

    /// A Stack zone's ceiling across the split: its members'
    /// ceilings and gaps summed where it lays them along that axis,
    /// the widest where it stacks them across it.
    private static func zoneCeiling(
        _ zone: RunZone,
        horizontal: Bool,
        _ context: LayoutContext
    ) -> CGFloat? {
        guard zone.vertical != horizontal else {
            return ceiling(of: zone.members, horizontal: horizontal, context)
        }
        var sum: CGFloat = 0
        for member in zone.members {
            guard
                let ceiling = context.learnedCeiling(
                    of: member,
                    horizontal: horizontal
                )
            else { return nil }
            sum += ceiling
        }
        let gap =
            horizontal
            ? context.gaps.inner.horizontal : context.gaps.inner.vertical
        return sum + gap * CGFloat(max(0, zone.members.count - 1))
    }

    /// One zone's frames with its windows sharing along it, each
    /// window its own container; nil where nothing moves and the
    /// zone's region is its slot's (`moved` false).
    private static func column(
        _ zone: RunZone,
        moved: Bool,
        _ context: LayoutContext
    ) -> [WindowID: CGRect]? {
        let laid = zone.frames(in: context)
        let along = !zone.vertical
        let rows = zone.members
            .compactMap { id in laid[id].map { (id: id, frame: $0) } }
            .sorted { lead($0.frame, along) < lead($1.frame, along) }
        let spans = rows.map { span($0.frame, along) }
        let shared = share(
            spans,
            ceilings: rows.map {
                context.learnedCeiling(of: $0.id, horizontal: along)
            }
        )
        guard shared != spans else { return moved ? laid : nil }
        var result = laid
        let frames = relaid(
            rows.map(\.frame),
            spans: shared,
            horizontal: along
        )
        for (row, frame) in zip(rows, frames) { result[row.id] = frame }
        return result
    }

    /// BSP: each split shares between its first window and the
    /// side holding every window after it, in the directions the
    /// slots split.
    static func bsp(
        _ windows: [WindowID],
        frames: [WindowID: CGRect],
        _ context: LayoutContext
    ) -> [WindowID: CGRect]? {
        let plan = BspLayout.plan(windows, in: context)
        guard windows.count > 1, plan.zone == nil else { return nil }
        let across = plan.splits
        var result = frames
        var moved = false
        var region = context.usable
        for (depth, side) in across.enumerated() {
            guard
                let parts = BspLayout.divide(region, sideBySide: side, context)
            else { return nil }
            let spans = [span(parts.first, side), span(parts.rest, side)]
            let shared = share(
                spans,
                ceilings: [
                    context.learnedCeiling(
                        of: windows[depth],
                        horizontal: side
                    ),
                    sideCeiling(
                        windows,
                        from: depth + 1,
                        across: across,
                        horizontal: side,
                        context
                    ),
                ]
            )
            moved = moved || shared != spans
            let sides = relaid(
                [parts.first, parts.rest],
                spans: shared,
                horizontal: side
            )
            result[windows[depth]] = sides[0]
            region = sides[1]
        }
        result[windows[windows.count - 1]] = region
        return moved ? result : nil
    }

    /// The ceiling of the BSP side holding `windows[depth...]`:
    /// its windows' ceilings summed with the gap across a split
    /// along `horizontal`, the larger of the two across one the
    /// other way; nil where any window has none.
    private static func sideCeiling(
        _ windows: [WindowID],
        from depth: Int,
        across: [Bool],
        horizontal: Bool,
        _ context: LayoutContext
    ) -> CGFloat? {
        guard
            let own = context.learnedCeiling(
                of: windows[depth],
                horizontal: horizontal
            )
        else { return nil }
        guard depth < across.count else { return own }
        guard
            let rest = sideCeiling(
                windows,
                from: depth + 1,
                across: across,
                horizontal: horizontal,
                context
            )
        else { return nil }
        guard across[depth] == horizontal else { return max(own, rest) }
        let gap =
            horizontal
            ? context.gaps.inner.horizontal : context.gaps.inner.vertical
        return own + gap + rest
    }

    /// Grid: the columns share their widths and the rows their
    /// heights. A track a spanning cell crosses, and an empty one,
    /// neither gives nor takes.
    static func grid(
        _ windows: [WindowID],
        frames: [WindowID: CGRect],
        _ context: LayoutContext
    ) -> [WindowID: CGRect]? {
        guard let shape = GridLayout.shape(for: windows, in: context),
            !shape.scrolls
        else { return nil }
        let members = Array(windows.prefix(shape.cells))
        let tracks = GridLayout.trackLengths(
            windows: windows,
            shape: shape,
            context: context
        )
        func ceilings(_ lengths: [CGFloat], _ horizontal: Bool)
            -> [CGFloat?]
        {
            lengths.indices.map { track in
                var held: [WindowID] = []
                for (index, id) in members.enumerated() {
                    let cell = GridLayout.cell(index, of: shape)
                    let span = horizontal ? cell.columns : cell.rows
                    guard span.first <= track, track <= span.last
                    else { continue }
                    guard span.first == span.last else {
                        return lengths[track]
                    }
                    held.append(id)
                }
                guard !held.isEmpty else { return lengths[track] }
                return ceiling(of: held, horizontal: horizontal, context)
            }
        }
        let shared = (
            widths: share(
                tracks.widths,
                ceilings: ceilings(tracks.widths, true)
            ),
            heights: share(
                tracks.heights,
                ceilings: ceilings(tracks.heights, false)
            )
        )
        guard
            shared.widths != tracks.widths
                || shared.heights != tracks.heights
        else { return nil }
        let cells = GridLayout.cells(
            tracks: shared,
            shape: shape,
            in: context
        )
        var result = frames
        for (id, cell) in zip(members, cells) { result[id] = cell }
        return result
    }
}
