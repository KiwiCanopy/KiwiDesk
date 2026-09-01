import KiwiDeskCore

/// Gaps & Borders row and container gate resolver (#678 Phase 3, 2026-08-03).
struct GapsBordersGates {
    let settings: TilingSettings

    /// Why a row or container is inert (`GapsBordersGateHelp`).
    enum InertReason: Hashable {
        case borderOff
        case glowOff
        case visualOff
        case gapsDiffer
    }

    /// Container-level gate reason.
    func containerReason(
        for container: SettingsContainer
    ) -> InertReason? {
        switch container {
        case .focusBorder:
            return settings.borderStyle.enabled ? nil : .borderOff
        default:
            return nil
        }
    }

    /// Row-level gate reason inside a live block.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .gaps(.outer):
            return outerGapsDiffer ? .gapsDiffer : nil
        case .gaps(.inner):
            return innerGapsDiffer ? .gapsDiffer : nil
        case .borders(.borderGlowSize):
            guard settings.borderStyle.enabled else { return nil }
            return settings.borderStyle.glow ? nil : .glowOff
        case .borders(.dragGhostBorder),
            .borders(.dragGhostFill):
            return settings.dragGhost.enabled ? nil : .visualOff
        case .borders(.dragDropZoneBorder),
            .borders(.dragDropZoneFill):
            return settings.dragDropZone.enabled
                ? nil : .visualOff
        default:
            // A gated key with no arm is a bug — fail loud in
            // debug, fail-OPEN in release so a shipped Settings
            // window never locks a row it cannot reason about
            // (mirrors `LayoutDefaultsGates`).
            assertionFailure(
                "unhandled Gaps & Borders gate: \(key.id)"
            )
            return nil
        }
    }

    /// Gated rows answered by this resolver (`everyGatedRowIsResolved`).
    static let resolved: Set<SettingKey> = [
        .gaps(.outer),
        .gaps(.inner),
        .borders(.borderGlowSize),
        .borders(.dragGhostBorder),
        .borders(.dragGhostFill),
        .borders(.dragDropZoneBorder),
        .borders(.dragDropZoneFill),
    ]

    /// Declared-but-answered-elsewhere set. The sticky-reach
    /// row's gate is a SURFACING hide answered by the renderer's
    /// own `model.canDriveDesktops` (#1145, the liquid-glass
    /// shape) — a machine capability this saved-config resolver
    /// cannot read.
    static let resolvedElsewhere: Set<SettingKey> = [
        .borders(.stickyDesktopReach)
    ]

    /// True if the strokes a shared MASTER row writes currently
    /// disagree. Deliberately NOT an `InertReason`: the gap
    /// masters grey because a per-edge drawer sits under them to
    /// repair from; these two have none, so greying them would
    /// state the disagreement and withhold the only control that
    /// ends it — they stay live and acknowledge through the `?`.
    func strokesDiffer(for key: SettingKey) -> Bool {
        switch key {
        case .borders(.borderWidthMaster):
            return widthsDiffer
        case .borders(.borderCornerMaster):
            return agreedCornerStyle == nil
        default:
            return false
        }
    }

    /// Agreed corner shape across ring style and drag radius —
    /// the ONE copy of that comparison: the master binding reads
    /// it as its displayed value and `strokesDiffer` as the `?`
    /// predicate, so the blank picker and its explanation cannot
    /// contradict.
    var agreedCornerStyle: BorderStyle.CornerStyle? {
        let fromRadius: BorderStyle.CornerStyle =
            settings.dragCornerRadius > 0 ? .rounded : .square
        return settings.borderStyle.cornerStyle == fromRadius
            ? fromRadius : nil
    }

    // MARK: - Predicates

    /// The three stored stroke widths, compared. The master
    /// keeps SHOWING the ring's — a slider has no blank state a
    /// user could act on the way an unselected segment is one.
    private var widthsDiffer: Bool {
        let width = settings.borderStyle.width
        return width != settings.dragGhost.borderWidth
            || width != settings.dragDropZone.borderWidth
    }

    /// The outer master is inert while its four edges disagree —
    /// there is no single value for it to show or write.
    private var outerGapsDiffer: Bool {
        let o = settings.gapsGlobal.outer
        return
            !(o.top == o.bottom
            && o.top == o.left
            && o.top == o.right)
    }

    /// The inner master is inert while its two axes disagree.
    private var innerGapsDiffer: Bool {
        let i = settings.gapsGlobal.inner
        return i.horizontal != i.vertical
    }
}
