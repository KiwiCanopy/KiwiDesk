import Foundation

extension WorkMeter {
    /// The `get_work_counters` reply: raw counts plus the
    /// derived rates #1508 asks for — durations in ms, per-call
    /// means in µs. `retile_ms` includes `bar_ms` and `border_ms`.
    /// The AX fields are null unless `countsAX`, which defaults to
    /// whether this is `.shared`: the static AX sites count only
    /// there, so an injected meter's AX columns cannot move.
    func report(reset: Bool, countsAX: Bool? = nil) -> JSONValue {
        let (c, seconds) = snapshot(reset: reset)
        let ax = countsAX ?? (self === Self.shared)
        func round2(_ value: Double) -> JSONValue {
            .number((value * 100).rounded() / 100)
        }
        func ms(_ nanos: Int) -> JSONValue { round2(Double(nanos) / 1e6) }
        func per(_ part: Int, _ whole: Int) -> JSONValue {
            whole == 0 ? .null : round2(Double(part) / Double(whole))
        }
        func perMs(_ nanos: Int, _ whole: Int) -> JSONValue {
            whole == 0 ? .null : round2(Double(nanos) / Double(whole) / 1e6)
        }
        func perUs(_ nanos: Int, _ whole: Int) -> JSONValue {
            whole == 0 ? .null : round2(Double(nanos) / Double(whole) / 1e3)
        }
        let count: (Int) -> JSONValue = { .number(Double($0)) }
        var out: [String: JSONValue] = [
            "seconds": round2(seconds),
            "events": count(c.events),
            "retiles": count(c.retiles),
            "retiles_per_second": seconds > 0
                ? round2(Double(c.retiles) / seconds) : .null,
            "retile_ms_mean": perMs(c.retileNanos, c.retiles),
            "retile_ms_max": ms(c.retileMaxNanos),
            "events_per_retile": per(c.events, c.retiles),
            "reissue_passes": count(c.reissuePasses),
            "space_switches": count(c.spaceSwitches),
            "bar_renders": count(c.barRenders),
            "bar_ms_mean": perMs(c.barNanos, c.barRenders),
            "bar_ms_max": ms(c.barMaxNanos),
            "bar_renders_per_switch": per(c.barRenders, c.spaceSwitches),
            "bar_shows_skipped": count(c.barShowsSkipped),
            "bar_content_redraws": count(c.barContentRedraws),
            "shelf_shows_skipped": count(c.shelfShowsSkipped),
            "space_bar_views_minted": count(c.spaceBarViewsMinted),
            "shelf_stands_skipped": count(c.shelfStandsSkipped),
            "border_syncs": count(c.borderSyncs),
            "border_ms_mean": perMs(c.borderNanos, c.borderSyncs),
            "border_ms_max": ms(c.borderMaxNanos),
            "frames_issued": count(c.framesIssued),
            "frames_skipped": count(c.framesSkipped),
            "parks_issued": count(c.parksIssued),
            "parks_skipped": count(c.parksSkipped),
            "passes_held": count(c.passesHeld),
            "passes_merged": count(c.passesMerged),
            "settle_passes": count(c.settlePasses),
            "settle_passes_held": count(c.settlePassesHeld),
            "settle_passes_merged": count(c.settlePassesMerged),
            "settle_frames_issued": count(c.settleFramesIssued),
            "settle_frames_skipped": count(c.settleFramesSkipped),
            "settle_parks_issued": count(c.settleParksIssued),
            "settle_parks_skipped": count(c.settleParksSkipped),
            "frames_coalesced": count(c.framesCoalesced),
            "queued_jobs": count(c.queuedJobs),
            "queue_wait_us_mean": perUs(c.queueWaitNanos, c.queuedJobs),
            "queue_wait_ms_max": ms(c.queueWaitMaxNanos),
        ]
        let axFields: [String: JSONValue] = [
            "ax_main_calls": count(c.axMainCalls),
            "ax_main_us_mean": perUs(c.axMainNanos, c.axMainCalls),
            "ax_main_ms_max": ms(c.axMainMaxNanos),
            "ax_main_ms_total": ms(c.axMainNanos),
            "ax_off_main_calls": count(c.axOffMainCalls),
            "ax_off_main_us_mean": perUs(
                c.axOffMainNanos,
                c.axOffMainCalls
            ),
            "ax_off_main_ms_total": ms(c.axOffMainNanos),
            "ax_calls_per_switch": per(
                c.axMainCalls + c.axOffMainCalls,
                c.spaceSwitches
            ),
        ]
        for (key, value) in axFields { out[key] = ax ? value : .null }
        return .object(out)
    }
}
