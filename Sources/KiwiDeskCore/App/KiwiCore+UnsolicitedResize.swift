import CoreGraphics
import Foundation

/// A resize nobody asked for — macOS's title-bar zoom, an edge
/// double-click's expand, an app re-sizing itself — is corrected
/// NOW rather than at the next unrelated retile (#1358, owner
/// ruling 2026-09-13): a tiled window goes back into its slot, an
/// effective float is fitted clear of the bars. Both are the
/// ordinary retile's own work; this only decides whether one is
/// owed, and bounds how often.
extension KiwiCore {
    /// Whether an unsolicited resize left `id` off the frame a
    /// SHOWN space gives it: a placed member off its slot beyond
    /// the retile tolerance — every display's shown space, since
    /// `calculatedFrames` places them all — or a float the bar
    /// sweep would move. Nil from either is "not placed" and
    /// answers no.
    func unsolicitedResizeLeavesOffFrame(
        _ id: WindowID,
        frame: CGRect
    ) -> Bool {
        if let slot = tiler.calculatedFrames(state: state)[id] {
            return !TilingEngine.close(frame, to: slot)
        }
        return floatFitCorrection(id, frame: frame) != nil
    }

    /// The `.windowResized` arm's correction for a resize that is
    /// neither our ask's echo nor a mouse gesture. Stands down
    /// while event retiles are deferred (#672) — the burst's one
    /// trailing pass corrects it — and past the memo's bound.
    func correctUnsolicitedResize(_ id: WindowID, frame: CGRect) {
        guard !defersEventRetiles else { return }
        let now = Date()
        guard unsolicitedResizeLeavesOffFrame(id, frame: frame)
        else {
            tiler.unsolicitedCorrections.noteOnFrame(id)
            return
        }
        guard tiler.unsolicitedCorrections.admit(id, now: now) else {
            onLog(
                "unsolicited resize of window \(id.raw) left "
                    + "standing: corrected twice, app keeps reverting"
            )
            return
        }
        onLog("unsolicited resize of window \(id.raw) corrected")
        retile(animated: tiler.settings.animations.onWindowResize)
    }
}

/// How often one window's unsolicited resize may be corrected
/// (#1358). An app that takes the slot and reverts LATER than
/// the applier's echo grace reads as unsolicited every time, and
/// each correction wipes the #677 ledger, so the twice-refused
/// rule can never accumulate to end it — this memo ends it
/// instead, on the same shape: two consecutive corrections and
/// the window is left standing until it is seen ON its frame
/// again, or the memo ages out. The age bound is the #1049 revive
/// tombstone's, one horizon for "this window misbehaved".
struct UnsolicitedResizeMemo {
    static let maxConsecutive = 2
    static let expiry: TimeInterval = 30

    private var entries: [WindowID: (count: Int, last: Date)] = [:]

    /// Whether a correction may issue; records it when so.
    mutating func admit(_ id: WindowID, now: Date) -> Bool {
        var entry = entries[id] ?? (0, now)
        if now.timeIntervalSince(entry.last) > Self.expiry {
            entry = (0, now)
        }
        guard entry.count < Self.maxConsecutive else { return false }
        entries[id] = (entry.count + 1, now)
        return true
    }

    /// A settled reading on the frame ends the run.
    mutating func noteOnFrame(_ id: WindowID) {
        entries[id] = nil
    }

    mutating func forget(_ id: WindowID) {
        entries[id] = nil
    }

    mutating func rekey(_ old: WindowID, to new: WindowID) {
        guard let entry = entries.removeValue(forKey: old)
        else { return }
        entries[new] = entry
    }
}
