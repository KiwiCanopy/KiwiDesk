import Foundation
import os

/// Signpost and duration surface for the boot path (#672).
///
/// Boot cost used to be invisible in the field: no signpost, no
/// log line carried a duration, so a hung helper process
/// serializing the whole scan (each AX call eating the default
/// messaging timeout) could not be told apart from ordinary
/// Electron warmup. The intervals emitted through this poster
/// surface every boot phase and each per-app attach/reconcile in
/// Instruments and `log`:
///
///     log show --signpost --last 5m --predicate \
///         'subsystem == "com.kiwicanopy.kiwidesk"'
///
/// Slow spans additionally log one plain line through the owning
/// subsystem's `onLog` seam, so a field report's syslog names the
/// offending app without Instruments attached.
enum BootSignpost {
    /// Keep this string equal to the `.app`'s
    /// `CFBundleIdentifier` (scripts/build-app.sh writes that
    /// one) — the whole point is that one subsystem predicate
    /// finds the app's log lines and these intervals together,
    /// so whoever changes either copy must change both.
    static let signposter = OSSignposter(
        subsystem: "com.kiwicanopy.kiwidesk",
        category: "boot"
    )

    /// An attach/reconcile span at or above this many
    /// milliseconds logs one line through `onLog`. Sized at the
    /// *floor* of the Electron/WebKit lazy-answer band
    /// (100–300 ms, accessibility.md) on purpose: a nontrivial
    /// warmup is itself boot-cost evidence worth one line (the
    /// baseline's 289 ms Obsidian attach was exactly the
    /// signal), while fast native apps stay quiet and a
    /// stalled app is always on record.
    static let slowSpanMs: Int64 = 100
}

extension Duration {
    /// Whole milliseconds, for log lines.
    var wholeMilliseconds: Int64 {
        components.seconds * 1_000
            + components.attoseconds / 1_000_000_000_000_000
    }
}
