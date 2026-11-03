import CoreGraphics

/// The two presses `RunZone.press` answers without a length step of
/// the window's own (#2709): beside only sized mates, and the run's
/// weight step.
extension RunZone {
    /// The press of the one window that draws what sized mates leave:
    /// the nearest mate's length moves the other way, and a grow past
    /// what that mate can give sets it to its floor and pushes on.
    func besideSized(
        _ line: Line,
        _ index: Int,
        by delta: CGFloat,
        toward side: PushSide
    ) -> Press {
        let sized = line.before.filter {
            $0 != index && line.weights[$0] == 0
        }
        let ahead = sized.filter { $0 < index }.max()
        let after = sized.filter { $0 > index }.min()
        guard let mate = side == .start ? ahead ?? after : after ?? ahead
        else { return Press(cue: .nothingToDivide, refusal: .alone) }
        let member = members[mate]
        var press = Press()
        // While it draws the rest the window keeps no length; a push
        // on past the mate's room gives it one below.
        press.sizes[members[index]] = .some(nil)
        if delta < 0 {
            let give = min(-delta, line.drawn[index] - line.bare[index])
            guard give > Self.unchangedTolerance else {
                return Press(cue: .ownMinimum, refusal: .atMinimum)
            }
            if give < -delta - Self.unchangedTolerance {
                press.cue = .ownMinimum
            }
            press.sizes[member] = share(of: line.drawn[mate] + give)
            return press
        }
        let room = line.drawn[mate] - line.bare[mate]
        guard delta > room else {
            press.sizes[member] = share(of: line.drawn[mate] - delta)
            return press
        }
        var given = line
        given.floors[mate] = line.bare[mate]
        given.drawn[mate] = line.bare[mate]
        given.drawn[index] += room
        let push = lengthStep(given, index, by: delta - room, toward: side)
        press.sizes[member] = .some(
            push.visible.contains(mate) ? share(of: line.bare[mate]) : nil
        )
        press.sizes[members[index]] = share(of: push.target)
        press.visible = push.visible
        press.movesRun = true
        return press
    }

    /// The run's weight step (#2235): it divides the span the shown
    /// windows' floors leave, among the windows that take a share,
    /// with no minimum of its own, since the layout keeps the floors.
    func weightStep(
        _ line: Line,
        _ index: Int,
        shown: [Int],
        by delta: CGFloat,
        in context: LayoutContext
    ) -> Press {
        guard shown.count > 1, let at = shown.firstIndex(of: index) else {
            return Press(cue: .nothingToDivide, refusal: .alone)
        }
        let extra = runExtra(in: context) ?? 0
        guard extra > 0 else {
            let anchor = members[shown[at == 0 ? 1 : at - 1]]
            return Press(
                cue: delta < 0 ? .ownMinimum : .neighborMinimum(anchor),
                refusal: .atMinimum
            )
        }
        var press = Press()
        press.weight =
            StackLayout.weightStep(
                weights: shown.map { line.weights[$0] },
                at: at,
                delta: Double(delta),
                span: Double(extra),
                minSizes: Array(repeating: 0, count: shown.count)
            ).value
        return press
    }
}
