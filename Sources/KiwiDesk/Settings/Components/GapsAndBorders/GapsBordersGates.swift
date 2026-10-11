import KiwiDeskCore

/// Gaps & Borders row and container gate resolver (#678 Phase 3, 2026-08-03).
struct GapsBordersGates {
    let settings: TilingSettings

    /// Why a row or container is inert (`GapsBordersGateHelp`).
    enum InertReason: Hashable, CaseIterable {
        case borderOff
        /// The Fit rows on the Gaps card read a border that is
        /// off — its own sentence, since "these settings" names
        /// the Focus Border card's rows (#1360).
        case fitBorderOff
        case glowOff
        case visualOff
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
        case .borders(.borderGlowSize),
            .borders(.borderGlowSizeAuto):
            guard settings.borderStyle.enabled else { return nil }
            return settings.borderStyle.glow ? nil : .glowOff
        case .borders(.dragGhostBorder),
            .borders(.dragGhostFill):
            return settings.dragGhost.enabled ? nil : .visualOff
        case .borders(.dragDropZoneBorder),
            .borders(.dragDropZoneFill):
            return settings.dragDropZone.enabled
                ? nil : .visualOff
        case .borders(.borderFitGaps),
            .borders(.borderFitGapsExtraSpacing):
            // Fit reads the border it sizes for (#1360).
            return settings.borderStyle.enabled
                ? nil : .fitBorderOff
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

    /// Masters that answer `followersDiffer` — the census of who
    /// acknowledges (`MasterDivergenceRegisterTests`); a master
    /// here carries no census gate.
    static let acknowledged: Set<SettingKey> = [
        .gaps(.outer),
        .gaps(.inner),
        // The KiwiShelf Position master (#1731) takes the same
        // acknowledging shape, so it answers here too.
        .kiwishelf(.edge),
    ]

    /// Gated rows answered by this resolver (`everyGatedRowIsResolved`).
    static let resolved: Set<SettingKey> = [
        .borders(.borderGlowSize),
        .borders(.borderGlowSizeAuto),
        .borders(.borderFitGaps),
        .borders(.borderFitGapsExtraSpacing),
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

    /// True if the values a MASTER row writes currently disagree.
    /// Deliberately NOT an `InertReason`: dimmed means "takes no
    /// input" on every channel, so a master stays live and
    /// acknowledges through its `?` — the first edit converges
    /// its followers (#1383). Routed through `acknowledged` so an
    /// arm added without joining the register is dead, not live.
    func followersDiffer(for key: SettingKey) -> Bool {
        guard Self.acknowledged.contains(key) else { return false }
        switch key {
        case .gaps(.outer):
            return outerGapsDiffer
        case .gaps(.inner):
            return innerGapsDiffer
        case .kiwishelf(.edge):
            return settings.uniformBarEdge == nil
        default:
            return false
        }
    }

    // MARK: - Predicates

    /// The outer master acknowledges while its four edges
    /// disagree — it shows the top edge and writes all four.
    private var outerGapsDiffer: Bool {
        Self.outerDiffers(settings.gapsGlobal)
    }

    /// Whether a value's four outer edges differ — the one copy
    /// both outer masters read (#1383, #1775).
    static func outerDiffers(_ gaps: Gaps) -> Bool {
        let o = gaps.outer
        return !(o.top == o.bottom && o.top == o.left && o.top == o.right)
    }

    /// The inner master acknowledges while its two axes disagree.
    private var innerGapsDiffer: Bool {
        Self.innerDiffers(settings.gapsGlobal)
    }

    /// Whether a value's two inner axes differ (#1383, #1775).
    static func innerDiffers(_ gaps: Gaps) -> Bool {
        gaps.inner.horizontal != gaps.inner.vertical
    }
}
