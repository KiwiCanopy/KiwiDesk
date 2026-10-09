import CoreGraphics
import Foundation

/// SkyLight's `dlsym` symbols as `self_test` probes them (#1889):
/// each row reads the resolved value this home holds, and a read
/// is checked against a second reader.
extension SkyLight {
    @MainActor
    static func selfTestProbes(
        _ context: PrivatePathContext
    ) -> [PrivatePathProbe] {
        spaceProbes() + writeProbes() + windowProbes(context)
    }

    @MainActor
    private static func spaceProbes() -> [PrivatePathProbe] {
        let home = "SkyLight"
        return [
            .read(
                "SLSMainConnectionID",
                home: home,
                resolved: { mainConnection != nil },
                verify: { PrivatePathVerify.connection(connection) }
            ),
            .read(
                "SLSGetActiveSpace",
                home: home,
                resolved: { getActiveSpace != nil },
                verify: {
                    PrivatePathVerify.activeSpace(
                        NativeSpaces.activeSpaceID(),
                        in: NativeSpaces.allSpaces()
                    )
                }
            ),
            .read(
                "SLSCopyManagedDisplaySpaces",
                home: home,
                resolved: { copyManagedDisplaySpaces != nil },
                verify: {
                    PrivatePathVerify.managedSpaces(
                        NativeSpaces.allSpaces()
                    )
                }
            ),
            .read(
                "SLSManagedDisplayGetCurrentSpace",
                home: home,
                resolved: { displayCurrentSpace != nil },
                verify: {
                    PrivatePathVerify.currentSpaces(
                        { NativeSpaces.currentSpace(displayUUID: $0) },
                        in: NativeSpaces.allSpaces()
                    )
                }
            ),
        ]
    }

    /// Writes the read-only run looks up and never calls.
    @MainActor
    private static func writeProbes() -> [PrivatePathProbe] {
        let home = "SkyLight"
        let writes: [(String, @MainActor () -> Bool)] = [
            ("SLSDisableUpdate", { disableUpdate != nil }),
            ("SLSReenableUpdate", { reenableUpdate != nil }),
            (
                "SLSSetConnectionProperty",
                { setConnectionProperty != nil }
            ),
            ("SLSTransactionCreate", { transactionCreate != nil }),
            ("SLSTransactionCommit", { transactionCommit != nil }),
            (
                "SLSTransactionMoveWindowWithGroup",
                { transactionMove != nil }
            ),
        ]
        return writes.map { name, resolved in
            .write(name, home: home, resolved: resolved)
        }
    }

    @MainActor
    private static func windowProbes(
        _ context: PrivatePathContext
    ) -> [PrivatePathProbe] {
        let home = "SkyLight"
        let radius: @MainActor () -> PrivatePathVerdict = {
            guard let own = context.ownWindow() else {
                return PrivatePathVerify.noOwnWindow
            }
            guard let value = windowCornerRadius(own.id) else {
                return .inconclusive(
                    "window \(own.id) answered no radius"
                )
            }
            return .works("window \(own.id): radius \(Int(value))")
        }
        let radiusSymbols: [(String, @MainActor () -> Bool)] = [
            ("SLSWindowQueryWindows", { windowQueryWindows != nil }),
            (
                "SLSWindowQueryResultCopyWindows",
                { queryResultCopyWindows != nil }
            ),
            ("SLSWindowIteratorGetCount", { iteratorGetCount != nil }),
            ("SLSWindowIteratorAdvance", { iteratorAdvance != nil }),
            (
                "SLSWindowIteratorGetCornerRadii",
                { iteratorGetCornerRadii != nil }
            ),
        ]
        return [
            .read(
                "SLSGetWindowBounds",
                home: home,
                resolved: { getWindowBounds != nil },
                verify: {
                    let own = context.ownWindow()
                    return PrivatePathVerify.bounds(
                        own.flatMap { windowBounds($0.id) },
                        of: own
                    )
                }
            ),
            .read(
                "SLSCopyWindowsWithOptionsAndTags",
                home: home,
                resolved: { copyWindowsWithOptionsAndTags != nil },
                verify: {
                    let census = context.census()
                    return PrivatePathVerify.answered(
                        census,
                        "\(census?.hosts.count ?? 0) windows listed"
                    )
                }
            ),
            .read(
                "SLSCopySpacesForWindows",
                home: home,
                resolved: { copySpacesForWindows != nil },
                verify: {
                    let own = context.ownWindow()
                    return PrivatePathVerify.hostedSpace(
                        own.map { context.spaceOfWindow(WindowID($0.id)) }
                            ?? .unavailable,
                        of: own
                    )
                }
            ),
        ]
            + radiusSymbols.map { name, resolved in
                .read(name, home: home, resolved: resolved, verify: radius)
            }
    }
}
