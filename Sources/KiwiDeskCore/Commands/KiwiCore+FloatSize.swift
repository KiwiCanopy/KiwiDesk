import CoreGraphics

/// `float_size` and `size_floating` (#3554): the size a centred
/// float takes, and the verb that snaps the focused float to it.
/// The size itself is `defaultFloatSize`'s, which the placement
/// reads too.
extension KiwiCore {
    /// `set_float_size(width, height)`; no arguments clears it,
    /// so a centred float takes the derived size again.
    func setFloatSize(_ args: [JSONValue]) -> CommandResponse {
        if args.isEmpty {
            tiler.settings.floatSize = nil
            return .ok()
        }
        guard let size = Self.floatSizeArgs(args) else {
            return .fail("expected positive width and height")
        }
        tiler.settings.floatSize = size
        // No retile: read only when a float is placed or sized.
        return .ok()
    }

    /// `size_floating([width, height])`: the focused float at the
    /// asked size, else `float_size`, else the derived size, kept
    /// centred where it is and confined to the region the placement
    /// measures in. A size the region or the app's learned bounds
    /// truncate cues. A user's own ask, so outside #3163's
    /// never-resize-to-fit.
    func sizeFloating(_ args: [JSONValue]) -> CommandResponse {
        var asked: CGSize?
        if !args.isEmpty {
            guard let size = Self.floatSizeArgs(args) else {
                return .fail("expected positive width and height")
            }
            asked = size.size
        }
        let target: FloatMoveTarget
        switch floatMoveFocus() {
        case .answered(let response): return response
        case .target(let focus): target = focus
        }
        let id = target.id
        let returned = endMaximizeBeforeFloatVerb(id)  // #3036
        let base =
            returned ?? tiler.commandedFrame(of: id) ?? target.window.frame
        let region = floatGrowBounds(on: target.space) ?? target.region
        let ask = asked ?? tiler.settings.floatSize?.size
        let answer = defaultFloatSize(
            of: id,
            in: region,
            asked: ask,
            floor: CGSize(
                width: plannedMinSize(of: id, axis: "x"),
                height: plannedMinSize(of: id, axis: "y")
            )
        )
        cueFloatSizeTruncation(id, answer)
        // A locked app takes its box whole, fitted to its ratio, as
        // a float resize does (#2973): springing it lands short.
        let lockedRatio = state.floatAspects[id]?.ratio
        let size =
            lockedRatio.map {
                FloatResize.fitted(answer.size, ratio: $0)
            } ?? answer.size
        let sized = floatMoveFrame(
            GeometryUtils.confine(
                CGRect(
                    x: base.midX - size.width / 2,
                    y: base.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                to: region
            ),
            for: target
        )
        guard sized != base else { return .ok() }
        tiler.applyFrame(
            id,
            from: base,
            to: sized,
            animated: tiler.settings.animations.onStateChange
                && lockedRatio == nil,
            sizing: .allSpringSized
        )
        holdRingForStateChange([id])
        // A size outside the layout's asks (#677), as the placement.
        tiler.forgetSizeBound(id)
        return .ok()
    }

    /// A width and a height, both finite and positive.
    static func floatSizeArgs(_ args: [JSONValue]) -> FloatSize? {
        guard args.count == 2,
            let width = args[0].numberValue,
            let height = args[1].numberValue
        else { return nil }
        return FloatSize(width: width, height: height)
    }

    /// Cues the first axis a limit moved off the asked size, by
    /// the limit `FloatPlacement.defaultSize` reports.
    private func cueFloatSizeTruncation(
        _ id: WindowID,
        _ answer: FloatPlacement.DefaultSize
    ) {
        for (axis, limit) in [("x", answer.width), ("y", answer.height)] {
            switch limit {
            case .floor: refuseShrinkAtMinimum(id, axis: axis)
            case .ceiling: refuseGrowAtMaximum(id, axis: axis)
            case .region: refuseGrowAtBoundary(id, axis: axis)
            case nil: continue
            }
            return
        }
    }
}
