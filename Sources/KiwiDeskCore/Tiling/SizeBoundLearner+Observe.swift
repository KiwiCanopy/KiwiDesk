import CoreGraphics
import Foundation

/// The learner's per-axis observation ladder, split out at the
/// file ceiling. `SizeBoundLearner` owns the ledgers and the
/// promotion; this is the decision that reads one answer and
/// says whether it seeds, confirms or clears.
extension SizeBoundLearner {
    mutating func observeAxis(
        _ id: WindowID,
        asked: CGFloat,
        current: CGFloat,
        baseline: CGFloat?,
        settledRead: Bool,
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>,
        echoComplied: WritableKeyPath<Ask, Bool>
    ) -> Bool {
        var confirmed = false
        if EffectiveSizeBound.matches(current, asked) {
            // Only a settled compliance is evidence the
            // constraint lifted (#1049) — a transient one is
            // the emulator mid-snap-back, and clearing on it
            // wiped the ladder every cycle. See `observe`.
            // An echo-channel compliance is REMEMBERED instead:
            // if this same ask is next observed OFF its size,
            // the pair promotes below.
            if settledRead {
                complied(id, asked: asked, axis: axis)
            } else {
                lastAsks[id]?[keyPath: echoComplied] = true
            }
            return false
        }
        // The comply-then-revoke pair confirms in ONE cycle
        // (#1049): the ladder needs "the same answer twice"
        // because a single refusal can be a stale pre-ask frame
        // reading as an answer — but a compliance echo proves
        // the window truly held the asked size moments ago, so
        // an off-ask reading that follows within the same ask
        // is the app actively revoking our size: one answer,
        // definitively attributed, no second dance needed. The
        // narrow trade: a USER resize landing inside the ask's
        // echo grace right after the compliance confirms a
        // false entry — it pins the window at the size the user
        // themselves chose, and the next genuine resize or
        // settled compliance clears it.
        // Untouched by #1083's settled-read rule, deliberately:
        // this arm fires only after an echo reported the window
        // AT the asked size, which is positive proof the window
        // took it — so the reading that follows is a change FROM
        // a known state, not a frame that might never have moved.
        // The stale-frame ambiguity #1083 closes needs the
        // opposite: two readings neither of which proved
        // anything.
        if lastAsks[id]?[keyPath: echoComplied] == true {
            lastAsks[id]?[keyPath: echoComplied] = false
            return promote(
                id,
                asked: asked,
                answered: current,
                axis: axis
            )
        }
        var candidateEntries =
            candidates[id]?[keyPath: axis] ?? []
        // The settled pre-ask size is a real prior observation:
        // unchanged through a whole animation of size-sets, it
        // completes "the same answer twice" without a second
        // probe cycle. Only a positive, trusted baseline counts
        // (a fresh window's .zero state is silence, not an
        // answer), and a live candidate for the ask keeps the
        // ordinary ladder.
        //
        // **Only a SETTLED read may take it (#1083).** On the
        // echo channel a reading equal to the baseline is
        // ambiguous — "the app refused" and "the app has not
        // redrawn yet" produce the identical frame — and under
        // load the second is ordinary for any app, fast ones
        // included. Promoting on it records our own latency as
        // the app's limit: device capture 2026-08-28 minted a
        // bound per press at exactly the pre-press width (984,
        // 954, 924, 894 — one resize step apart), then refused
        // the next press against it, and a window resized both
        // ways ended pinned between a false minimum and a false
        // maximum. The settle probe is the read that can tell
        // the two apart, because it waits out
        // `sizeBoundProbeGraceSeconds` — which is what
        // "unchanged through a whole animation" means and what
        // this arm always intended.
        if settledRead,
            let baseline,
            baseline > 0,
            EffectiveSizeBound.matches(baseline, current),
            !candidateEntries.contains(where: {
                EffectiveSizeBound.matches($0.asked, asked)
            })
        {
            return promote(
                id,
                asked: asked,
                answered: current,
                axis: axis
            )
        }
        if let index = candidateEntries.firstIndex(where: {
            EffectiveSizeBound.matches($0.asked, asked)
        }) {
            let prior = candidateEntries[index]
            if EffectiveSizeBound.matches(
                prior.answered,
                current
            ) {
                // Twice in a row — but only a SETTLED second
                // reading is a second OBSERVATION (#1083).
                // Device capture 2026-08-28: two raw echoes 72
                // ms apart satisfied this at load average 8.7,
                // and no app redraws in 72 ms — that is one
                // stale frame counted twice, and it minted the
                // same false bound the baseline arm did (two
                // windows confirming an identical 1231x1011,
                // which is the drawn slot, not an app's limit).
                // A raw repeat therefore keeps the candidate
                // standing so the probe can confirm it.
                if settledRead {
                    confirmed = promote(
                        id,
                        asked: asked,
                        answered: current,
                        axis: axis
                    )
                    candidateEntries.remove(at: index)
                }
            } else {
                // Same ask, different answer: restart this
                // ask's ladder on the newest observation.
                candidateEntries[index] =
                    EffectiveSizeBound.Axis(
                        asked: asked,
                        answered: current
                    )
            }
        } else {
            candidateEntries.append(
                EffectiveSizeBound.Axis(
                    asked: asked,
                    answered: current
                )
            )
            if candidateEntries.count > Self.maxEntriesPerAxis {
                candidateEntries.removeFirst()
            }
        }
        writeCandidates(
            id,
            entries: candidateEntries,
            axis: axis
        )
        return confirmed
    }

}
