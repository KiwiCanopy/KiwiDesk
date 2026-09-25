import Foundation

/// The core's tunable waits, one value so tests assign any of
/// them at once; production keeps the defaults.
struct CoreTimings {
    /// Adoption-heal cadence (#675). 5 s: a healthy tick is one
    /// ~1 ms census, so the cadence only bounds worst-case
    /// latency.
    var adoptionHealInterval: Duration = KiwiCore.adoptionHealDefault
    /// Transient re-track wait (#675): 750 ms outlasts a Dock
    /// zoom, a fade-in or a close's teardown (#1157).
    var transientRetrackDelay: Duration = .milliseconds(750)
    /// The quiet a screen-count change waits for (#1612); nil
    /// settles inline, which `makeTestCore` pins.
    var monitorSettleDelay: Duration? = KiwiCore.monitorSettleDefault
}
