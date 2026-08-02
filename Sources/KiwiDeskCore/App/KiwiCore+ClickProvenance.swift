import AppKit
import Foundation

/// Click provenance for the focus-echo reverts (#687): which
/// managed window a left press REACHED, resolved at press time,
/// and whether a fresh click reached a reported window. Split
/// from `KiwiCore+FocusEvents.swift` (350-line ceiling); the
/// press stamp in `KiwiCore+Lifecycle` and the two echo reverts
/// in `KiwiCore+FocusEvents` are the consumers.
extension KiwiCore {
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
