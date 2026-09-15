import Foundation

/// How one layout pass treats a frame already in place and a
/// bound already learned (#1055/#1488). A property of the whole
/// PASS, chosen at the call site — `RetilePassRoutingTests`'
/// `allowed` map is the one list of who chooses what, and why —
/// because the probe used to ride the re-issue flag, and a
/// Space switch that only needed the re-issue probed too, under
/// which the automatic track count and every heal stand down.
public enum RetilePass: Sendable, Equatable {
    /// Event-driven: a frame inside the ±2 pt tolerance stays
    /// where the echo left it, and a corroborated bound is
    /// consumed rather than re-asked.
    case event
    /// Every frame re-issued — a Space or Desktop switch, whose
    /// echoes lag and would strand windows mid-transition — with
    /// bounds still consumed.
    case reissue
    /// An explicit `set_*` apply (AGENTS.md §5): every frame
    /// re-issued AND every corroborated bound probed once, so the
    /// user's own re-apply clears a stale bound (#1055).
    case apply

    /// Whether the "already there" tolerance is skipped.
    var reissues: Bool { self != .event }
    /// Whether the pass asks past corroborated bounds.
    var probes: Bool { self == .apply }
}
