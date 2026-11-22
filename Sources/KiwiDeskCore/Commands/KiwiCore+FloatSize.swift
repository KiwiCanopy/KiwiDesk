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
    /// centred where it is and confined to its float region. A
    /// size the region or the app's learned bounds truncate cues.
    /// A user's own ask, so outside #3163's never-resize-to-fit.
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
        let ask = asked ?? tiler.settings.floatSize?.size
        let size = defaultFloatSize(of: id, in: target.region, asked: ask)
        if let ask { cueFloatSizeTruncation(id, asked: ask, got: size) }
        let sized = floatMoveFrame(
            GeometryUtils.confine(
                CGRect(
                    x: base.midX - size.width / 2,
                    y: base.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                to: target.region
            ),
            for: target
        )
        guard sized != base else { return .ok() }
        tiler.applyFrame(
            id,
            from: base,
            to: sized,
            animated: tiler.settings.animations.onStateChange,
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

    /// Cues the first axis `got` missed `asked` on: a learned floor
    /// raising it, else the app's ceiling or the region capping it.
    private func cueFloatSizeTruncation(
        _ id: WindowID,
        asked: CGSize,
        got: CGSize
    ) {
        let bound = tiler.sizeBound(for: id)
        let axes: [(String, CGFloat, CGFloat, CGFloat?)] = [
            ("x", asked.width, got.width, bound?.maxWidth),
            ("y", asked.height, got.height, bound?.maxHeight),
        ]
        let epsilon = Self.resizeTruncationEpsilon
        for (axis, want, landed, ceiling) in axes {
            if landed > want + epsilon {
                refuseShrinkAtMinimum(id, axis: axis)
                return
            }
            if landed < want - epsilon {
                if let ceiling, landed >= ceiling - epsilon {
                    refuseGrowAtMaximum(id, axis: axis)
                } else {
                    refuseGrowAtBoundary(id, axis: axis)
                }
                return
            }
        }
    }
}
