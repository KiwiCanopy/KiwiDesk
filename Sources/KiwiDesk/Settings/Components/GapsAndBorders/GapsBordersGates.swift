import KiwiDeskCore

/// The Gaps & Borders area's greying, resolved from the census
/// (#678 Phase 3). Keyed on a row's own `SettingKey` over
/// `TilingSettings`, returning a REASON case rather than a Bool
/// — the shape General and Layout Defaults already share, so
/// this area adds no new resolver signature (owner ruling
/// 2026-08-03: converge Bars/Shortcuts onto it in a later PR,
/// not here).
///
/// Unlike Layout Defaults this area carries all three gate
/// flavours, so the resolver answers two questions:
///
/// - `containerReason(for:)` — the Focus-border block gate. Every
///   row in `.focusBorder` is inert while the ring is off, except
///   the enable toggle that owns the gate (`exemptFromContainer\
///   Gate`). The block draws one grey with one sentence, so the
///   gate resolves once at the container, not per row.
/// - `inertReason(for:)` — the row gates inside a live block:
///   the glow-size row (glow off), each drag column's Border and
///   Fill toggles (the visual itself off) and the two gap
///   masters (their edges / axes differ, the
///   `.runtime(.perEdgeValuesDiffer)` gate).
///
/// Returning the reason rather than a Bool keeps the grey and its
/// inline sentence from being two decisions that can disagree
/// (`GapsBordersGateHelp` renders it). The reason cases keep the
/// whole resolver assertable off the main actor.
struct GapsBordersGates {
    let settings: TilingSettings

    /// Why a row (or the Focus-border block) is inert. One case
    /// per predicate; the sentence lives in `GapsBordersGateHelp`.
    enum InertReason: Hashable {
        case borderOff
        case glowOff
        case visualOff
        case gapsDiffer
    }

    /// The one container gate in this area: the Focus-border block
    /// is inert while the ring is off. Other containers gate
    /// nothing.
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

    /// The row / runtime gate for a row inside a LIVE block. The
    /// container gate is the block's job, so a Focus-border row's
    /// reason here never repeats `.borderOff` — it guards on the
    /// ring being enabled first.
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
            // A gated key with no arm here is a bug: the census
            // declared a gate this resolver cannot answer. Fail
            // loud in debug, fail-open in release so a shipped
            // Settings window never locks a row it can't reason
            // about (mirrors `LayoutDefaultsGates`).
            assertionFailure(
                "unhandled Gaps & Borders gate: \(key.id)"
            )
            return nil
        }
    }

    /// The gated rows this resolver answers (data, so
    /// `everyGatedRowIsResolved` reds when a new census gate lands
    /// in neither set). The Focus-border CONTAINER gate is held
    /// separately by `containerGateIsResolved`.
    static let resolved: Set<SettingKey> = [
        .gaps(.outer),
        .gaps(.inner),
        .borders(.borderGlowSize),
        .borders(.dragGhostBorder),
        .borders(.dragGhostFill),
        .borders(.dragDropZoneBorder),
        .borders(.dragDropZoneFill),
    ]

    /// Declared-but-answered-elsewhere. Empty and kept so a new
    /// gate this resolver cannot answer must land here on purpose
    /// rather than pass silently.
    static let resolvedElsewhere: Set<SettingKey> = []

    // MARK: - Predicates

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
