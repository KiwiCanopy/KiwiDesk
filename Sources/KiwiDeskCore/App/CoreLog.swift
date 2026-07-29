import Foundation

/// The syslog write under every `var onLog` seam in Core, and
/// under `KiwiCore.onLog` itself.
///
/// **Where the default is actually operative.** Not, as it is
/// tempting to say, "whenever someone forgets to wire a seam":
/// bootstrap assigns all of them and `LogSeamWiringTests` reds if
/// one is missed, so in every case that guard *sees*, this
/// default never runs. It is load-bearing precisely in that
/// guard's documented open limits — a second instance of a
/// seam-owning type, an entry in its `allowed` map, and a seam
/// wired later than bootstrap, which
/// `.claude/rules/core-boundaries.md` explicitly carves out. In
/// those a seam really does run on its default, and the choice
/// between this and `{ _ in }` is the choice between a line that
/// skips the sink and a line that is dropped.
///
/// That is a smaller failure, not the absence of one: a seam
/// running on this default still bypasses `KiwiCore.onLog`, so
/// test capture and the GUI console `KiwiCore.onLog`'s own
/// comment anticipates would not carry it. The wiring rule stays
/// the obligation; this only sets what a violation costs.
///
/// A namespace of its own rather than a static on `KiwiCore`
/// because `KiwiCore` is already a class spread over thirty-odd
/// `KiwiCore+*.swift` extensions, and hanging general-purpose
/// primitives on it is how it got that way — not because a leaf
/// naming another subsystem is itself a problem, which this tree
/// does freely (`BorderManager.readWindowBounds` defaults to
/// `SkyLight.windowBounds`).
enum CoreLog {
    /// Writes one diagnostic line to syslog, under the same
    /// `KiwiDesk:` prefix the seams' lines already carried.
    ///
    /// `write`, not `emit`: this codebase spends `emit` on
    /// publishing to the `EventBus` (`EventBus.emit`, and the
    /// `KiwiCore.emit*` family), and a logger borrowing that verb
    /// for something that reaches no subscriber reads as an
    /// event that quietly goes nowhere.
    ///
    /// Left `nonisolated`: it touches nothing isolated, so it
    /// converts into the seams' `@MainActor (String) -> Void`
    /// without pinning the write itself to the main actor.
    ///
    /// Not `public`, and `LogSeamSinkTests` keeps it a default
    /// rather than a bypass — it asserts this body still writes,
    /// and that Core reaches this symbol only through a seam
    /// declaration. Both matter: gutting the body would restore
    /// the pre-#624 behaviour with every seam still naming it,
    /// and a direct call would put a diagnostic in syslog that
    /// `KiwiCore.onLog` never sees. `LogSeamDefaultTests` is the
    /// other half — that every seam names this in the first
    /// place.
    static func write(_ message: String) {
        NSLog("KiwiDesk: %@", message)
    }
}
