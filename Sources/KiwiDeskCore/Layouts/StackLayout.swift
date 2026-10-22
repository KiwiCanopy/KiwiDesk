import CoreGraphics

/// Master/Stack layout over flat window array (#222).
public struct StackLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }
        guard let zones = Self.zones(for: windows, in: context) else {
            return OverlapStack.frames(
                for: windows,
                in: context.usable,
                minSize: context.minWindowSize
            )
        }
        var result: [WindowID: CGRect] = [:]
        for zone in zones {
            result.merge(zone.frames(in: context)) { _, new in new }
        }
        return result
    }

    /// The master zone, then the stack zone where one is drawn —
    /// the regions every member is laid along (#222, #2235); nil
    /// where the two zones cannot both keep the minimum size and
    /// every window piles over the whole area (#44).
    public static func zones(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [RunZone]? {
        let usable = context.usable
        guard !windows.isEmpty else { return [] }
        let params = context.stack
        let (master, stack) = partition(
            windows,
            masterCount: params.masterCount
        )
        // Mirrored master order keeps boundary master at stack seam (#313).
        let masterOrdered =
            mirrorsMasterZone(params)
            ? Array(master.reversed())
            : Array(master)
        let masterVertical = params.masterOrientation == .vertical
        let horizontal = params.stackPosition.splitsHorizontally
        let gap =
            horizontal
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let available =
            (horizontal ? usable.width : usable.height) - gap
        let range = SplitDomain.effectiveRatioRange(
            available: Double(available),
            minSize: Double(
                context.minWindowSize.along(horizontal: horizontal)
            )
        )
        func split(_ range: ClosedRange<Double>)
            -> (master: CGRect, stack: CGRect)
        {
            let span = Self.masterSpan(
                available: available,
                ratio: params.masterRatio,
                in: range
            )
            return Self.regions(
                usable: usable,
                position: params.stackPosition,
                masterSpan: span,
                stackSpan: available - span,
                gap: gap
            )
        }
        guard let stack else {
            // Master only: the full usable region — unless the one
            // window keeps its zone (#1389).
            let region =
                range.map { range in
                    loneMasterKeepsZone(
                        windows,
                        params: params,
                        range: range
                    ) ? split(range).master : usable
                } ?? usable
            return [
                RunZone(
                    members: masterOrdered,
                    region: region,
                    vertical: masterVertical
                )
            ]
        }
        guard let range else { return nil }
        let halves = split(range)
        return [
            RunZone(
                members: masterOrdered,
                region: halves.master,
                vertical: masterVertical
            ),
            RunZone(
                members: Array(stack),
                region: halves.stack,
                vertical: params.stackPosition.stackOrientation
                    == .vertical
            ),
        ]
    }

    /// Whether master zone renders from stack seam (`StackSchematic`, #313).
    public static func mirrorsMasterZone(
        _ params: StackParams
    ) -> Bool {
        let leads =
            params.stackPosition == .left
            || params.stackPosition == .top
        guard leads else { return false }
        let parallel: StackParams.Orientation =
            params.stackPosition.splitsHorizontally
            ? .horizontal : .vertical
        return params.masterOrientation == parallel
    }

    /// Whether the split RENDERS its ratio for a lone member: with
    /// `fill_when_alone` off the one window keeps the master zone
    /// the two-window split gives it (#1389). The one home of that
    /// verdict — the engine draws by it and the resize cues judge
    /// "nothing to divide" by it (#1258), never by a member count.
    /// `range` is `SplitDomain.effectiveRatioRange`'s answer for
    /// the region: nil means no two zones fit, and the window
    /// fills.
    public static func loneMasterKeepsZone(
        _ windows: some Collection<WindowID>,
        params: StackParams,
        range: ClosedRange<Double>?
    ) -> Bool {
        windows.count == 1 && !params.fillWhenAlone && range != nil
    }

    /// The master zone's span: the stored ratio clamped into the
    /// range both zones can keep `minWindowSize` in (#44).
    static func masterSpan(
        available: CGFloat,
        ratio: Double,
        in range: ClosedRange<Double>
    ) -> CGFloat {
        available
            * CGFloat(
                min(max(ratio, range.lowerBound), range.upperBound)
            )
    }

    /// Master and stack regions for split of usable area (#222);
    /// public for the schematic's lone frame (#1389).
    public static func regions(
        usable: CGRect,
        position: StackParams.StackPosition,
        masterSpan: CGFloat,
        stackSpan: CGFloat,
        gap: CGFloat
    ) -> (master: CGRect, stack: CGRect) {
        switch position {
        case .right:
            let master = CGRect(
                x: usable.minX,
                y: usable.minY,
                width: masterSpan,
                height: usable.height
            )
            let stack = CGRect(
                x: usable.minX + masterSpan + gap,
                y: usable.minY,
                width: stackSpan,
                height: usable.height
            )
            return (master, stack)
        case .left:
            let stack = CGRect(
                x: usable.minX,
                y: usable.minY,
                width: stackSpan,
                height: usable.height
            )
            let master = CGRect(
                x: usable.minX + stackSpan + gap,
                y: usable.minY,
                width: masterSpan,
                height: usable.height
            )
            return (master, stack)
        case .bottom:
            let master = CGRect(
                x: usable.minX,
                y: usable.minY,
                width: usable.width,
                height: masterSpan
            )
            let stack = CGRect(
                x: usable.minX,
                y: usable.minY + masterSpan + gap,
                width: usable.width,
                height: stackSpan
            )
            return (master, stack)
        case .top:
            let stack = CGRect(
                x: usable.minX,
                y: usable.minY,
                width: usable.width,
                height: stackSpan
            )
            let master = CGRect(
                x: usable.minX,
                y: usable.minY + stackSpan + gap,
                width: usable.width,
                height: masterSpan
            )
            return (master, stack)
        }
    }
}
