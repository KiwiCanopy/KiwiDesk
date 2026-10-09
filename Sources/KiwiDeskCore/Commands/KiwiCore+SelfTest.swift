import Foundation

extension KiwiCore {
    /// `self_test` (#1889): every private fast path's verdict,
    /// read-only. The census and the per-window Space reach the
    /// probes through the compositor doors, never the builder.
    func selfTest() -> CommandResponse {
        let context = PrivatePathContext(
            ownWindow: PrivatePathContext.firstOwnWindow,
            census: { [self] in
                desktopMemory.readCensus(NativeSpaces.allSpaces())
            },
            spaceOfWindow: { [self] id in
                desktopMemory.readWindowSpace(id)
            }
        )
        return .ok(
            PrivatePathSelfTest.report(
                PrivatePathSelfTest.catalog(context),
                macOS: ProcessInfo.processInfo
                    .operatingSystemVersionString
            )
        )
    }
}
