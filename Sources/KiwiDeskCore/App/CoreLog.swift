import Foundation

/// The syslog write under every `var onLog` seam in Core, and
/// under `KiwiCore.onLog` itself.
///
/// It is a **default**, not a bypass. Bootstrap overwrites every
/// seam with a closure forwarding to `KiwiCore.onLog`
/// (`KiwiCore+Bootstrap`), whose own default is this function, so
/// a wired seam's line travels `subsystem.onLog → KiwiCore.onLog
/// → CoreLog.emit`. What the default decides is only what happens
/// when that wiring never runs.
///
/// **Why every seam defaults here rather than to `{ _ in }`.**
/// The omission `LogSeamWiringTests` exists to catch — a seam
/// declared and never assigned, compiling and shipping while it
/// drops every line it logs — costs *silence* under a no-op
/// default: no red, no warning, and the only symptom is a
/// diagnostic that was never going to appear, missed months
/// later by whoever needed it. Under this one the same omission
/// costs a routing inconsistency instead: the line still reaches
/// syslog, it just skips the sink a GUI console would read from.
/// Same mistake, lower stakes — which is the whole of the
/// argument, and it is worth being precise that it buys
/// robustness against a *future* omission rather than fixing a
/// present silence. `LogSeamDefaultTests` keeps the seams on this
/// default; `LogSeamWiringTests` keeps them wired.
///
/// A namespace of its own rather than `KiwiCore`'s default
/// hoisted to a static on `KiwiCore`, so that leaf subsystems do
/// not name the composition root in their property defaults.
public enum CoreLog {
    /// Writes one diagnostic line to syslog, under the
    /// `KiwiDesk:` prefix every Core log line carries.
    ///
    /// Left `nonisolated`: it touches nothing isolated, so it
    /// converts into the seams' `@MainActor (String) -> Void`
    /// without pinning the write itself to the main actor.
    public static func emit(_ message: String) {
        NSLog("KiwiDesk: %@", message)
    }
}
