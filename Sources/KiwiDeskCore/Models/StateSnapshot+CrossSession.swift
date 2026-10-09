import Foundation

extension StateSnapshot {
    /// This arrangement re-keyed onto the live windows a cross-
    /// session match paired (#1385), old id → live id: what the
    /// boot replay restores. An unpaired id is dropped, and so is
    /// every record keyed only by ids — pending filings, holds,
    /// the #1230 records — or private to a session.
    func rekeyed(_ ids: [WindowID: WindowID]) -> StateSnapshot {
        func live(_ raw: UInt32) -> WindowID? { ids[WindowID(raw)] }
        let records: [WindowRecord] = windows.compactMap { record in
            live(record.id).map {
                WindowRecord(
                    id: $0,
                    frame: record.frame,
                    app: record.app,
                    title: record.title
                )
            }
        }
        let rows: [SpaceRecord] = spaces.map { record in
            let weights = record.trackWeights.compactMap { raw, weight in
                live(raw).map { ($0, weight) }
            }
            return SpaceRecord(
                space: Space(
                    id: SpaceID(record.id),
                    mode: record.mode,
                    windows: record.windows.compactMap(live),
                    focused: record.focused.flatMap(live),
                    trackBreaks: Set(record.trackBreaks.compactMap(live)),
                    trackWeights: Dictionary(
                        weights,
                        uniquingKeysWith: { first, _ in first }
                    )
                )
            )
        }
        return StateSnapshot(
            windows: records,
            spaces: rows,
            activeSpace: activeSpace,
            capturedAt: capturedAt,
            arrangement: arrangement
        )
    }
}
