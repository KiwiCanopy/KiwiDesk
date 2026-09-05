import AppKit
import Foundation

/// Click provenance for the focus-echo reverts (#687): which
/// managed window a left press REACHED, resolved at press time,
/// and whether a fresh click reached a reported window. Split
/// from `KiwiCore+FocusEvents.swift` (350-line ceiling); the
/// press stamp in `KiwiCore+Lifecycle` and the two echo reverts
/// in `KiwiCore+FocusEvents` are the consumers.
extension KiwiCore {
    /// How long after a z-order raise its focus echo may still
    /// arrive and be reverted (#418/#425). Sized to the slowest
    /// AX responders (Electron/WebKit, ~100-300 ms, §5) with
    /// ~3x margin; a deliberate CLICKLESS focus of a stamped
    /// window inside it is eaten once — clicks escape on
    /// provenance (#687). Tunable.
    static let zOrderRaiseEchoWindow: TimeInterval = 1.0

    /// How long after KiwiDesk's own focus raise a report for
    /// that window is still its echo, a lazy app's ~150 ms
    /// duplicate included (#887). Sized like
    /// `zOrderRaiseEchoWindow`; beyond ~1 s a report is a user
    /// action.
    static let selfRaiseEchoWindow: TimeInterval = 1.0

    /// `id`'s self-raise stamp while it is LIVE, nil once past
    /// `selfRaiseEchoWindow` — the one freshness reading every
    /// consumer takes (#687/#689). Read, never consumed (#887).
    func selfRaiseStamp(
        _ id: WindowID,
        now: Date
    ) -> Date? {
        guard let stamp = selfRaiseStamps[id],
            now.timeIntervalSince(stamp) < Self.selfRaiseEchoWindow
        else { return nil }
        return stamp
    }

    /// Whether a report for `id` is our own focus raise's echo.
    func freshSelfRaise(
        _ id: WindowID,
        now: Date
    ) -> Bool {
        selfRaiseStamp(id, now: now) != nil
    }

    /// The self ledger's one MINTER (`PlacementBounceSeamTests`
    /// holds the write sites): stamps `id` as raised by us, and
    /// prunes by age so never-echoed raises cannot accrete.
    func stampSelfRaise(_ id: WindowID, now: Date) {
        selfRaiseStamps = selfRaiseStamps.filter {
            now.timeIntervalSince($0.value) < Self.selfRaiseEchoWindow
        }
        selfRaiseStamps[id] = now
    }

    /// Whether a live self-raise of `id` vetoes the z-order echo
    /// revert (#431): only when NEWER than the z-order stamp,
    /// never on freshness — an older one is the restore's own
    /// echo (#887, docs/design-decisions.md).
    func selfRaiseVetoesRevert(
        _ id: WindowID,
        now: Date
    ) -> Bool {
        guard let own = selfRaiseStamp(id, now: now) else {
            return false
        }
        return own > (zOrderRaiseEchoes[id] ?? .distantPast)
    }

    /// Whether a left click within the echo window actually
    /// REACHED `id` — the raise-echo revert's provenance escape
    /// (#687). Deliberately stricter than `recentClickInside`:
    /// containment alone is ambiguous here, because edge-pile
    /// frames overlap, so a slow pile-mate's late echo can
    /// contain the click point too — honoring it would pan the
    /// row onto a window the user did not click. Which window
    /// the press hit was resolved at press time
    /// (`clickReachedWindow` carries the argument); this only
    /// asks whether that click is fresh and hit `id`.
    func recentClickReached(
        _ id: WindowID,
        now: Date
    ) -> Bool {
        guard let click = lastLeftClick,
            now.timeIntervalSince(click.at)
                < Self.zOrderRaiseEchoWindow
        else { return false }
        return click.reached == id
    }

    /// The managed window a left press at `point` (AX coords)
    /// hit: the frontmost stacking entry whose state frame
    /// contains the point. Called by the `KiwiCore+Lifecycle`
    /// press stamp, AT PRESS TIME deliberately: provenance is a
    /// press-time fact. Resolving it when the echo arrives read
    /// a stacking a drain may have churned since — a quiet
    /// raise of a same-app sibling reorders above the app's key
    /// window (`restoreMonocleZOrder`'s churn note) — against
    /// frames a retile may have moved, so a stamped sibling
    /// could forge the escape (architect review, 2026-08-03).
    /// At press time the frontmost window at the point IS the
    /// window the press lands in.
    ///
    /// Frontmost MANAGED window, deliberately: candidates the
    /// state does not track are skipped, so a click on a
    /// non-click-through IGNORED window (a quick-terminal
    /// panel) overlapping a stamped window can still resolve to
    /// the window beneath. Accepted: narrow, and it fails
    /// toward honoring a focus report, never toward eating one.
    /// An unwired provider answers nil — no provenance.
    func clickReachedWindow(at point: CGPoint) -> WindowID? {
        // A press inside a painted bar strip reached no managed
        // window — the bar (KiwiDesk's own overlay, absent from
        // state) absorbed it, and resolving THROUGH it would
        // hand the window beneath a provenance it never earned:
        // a bar click over a stamped pile would then escape
        // that pile-mate's echo revert (device QA 2026-08-03,
        // `reach` resolving through the bar).
        let absorbed =
            appBars.shownStrips.contains {
                $0.strip.contains(point)
            }
            || spaceBars.shownStrips.contains {
                $0.strip.contains(point)
            }
        guard !absorbed,
            let stacking = stackingOrderProvider?()
        else { return nil }
        for candidate in stacking {
            guard
                let frame = state.windows[candidate]?.frame,
                frame.contains(point)
            else { continue }
            return candidate
        }
        return nil
    }
}
