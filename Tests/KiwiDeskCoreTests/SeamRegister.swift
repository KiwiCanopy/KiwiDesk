@testable import KiwiDeskCore

/// Which of the conformers above the walk must actually **reach**
/// on a live core, checked as an equality rather than a floor.
///
/// This is the register that makes the list above honest, and it
/// is the assertion that matters most here. Three of the walk's
/// failure modes are fail-shut — depth truncation gaps, an
/// unresolvable node gaps, a reached-but-unconformed owner is
/// named — but **reachability is fail-open**, and a probe of
/// seven seams asserts `[7] == [7]` just as happily as eight.
/// Measured ways an owner leaves the graph with no signal at all:
/// moving it behind a computed accessor over a `static`, holding
/// it in a superclass-declared property, an unforced `lazy var`,
/// and a `CustomReflectable` that curates `children`. The first
/// is an ordinary refactor — a process-wide `ExecLauncher` is a
/// natural reading of #467's in-flight dedup — and with the seam
/// then broken, both this suite and `LogSeamWiringTests` pass.
///
/// A count would be the number-pin `rule-authoring.md` warns
/// against; runtime cannot enumerate conformances, so a named set
/// is the only register available. It earns disposition 5 by
/// sitting against the list it mirrors: an author adding a ninth
/// conformance has this on screen. A conformer that becomes
/// genuinely unreachable moves to `unreachable` with its reason,
/// the shape `LogSeamWiringTests.allowed` already uses.
enum SeamRegister {
    static let reachable: Set<String> = [
        "AnimationEngine",
        "BorderManager",
        "CrashRecovery",
        "EventBus",
        "ExecLauncher",
        "KeybindingManager",
        "ProfileManager",
        "SocketServer",
    ]

}
