import CoreGraphics
import Foundation

/// SkyLight's `dlsym` symbols as `self_test` probes them (#1889):
/// each row is named and judged by the `PrivateSymbol` this home
/// holds, and a read is checked against a second reader where one
/// exists — or says it is liveness only.
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
            // Liveness only: nothing else reads the connection.
            .read(mainConnectionSymbol.resolution, home: home) {
                PrivatePathVerify.connection(connection)
            },
            .read(getActiveSpaceSymbol.resolution, home: home) {
                PrivatePathVerify.activeSpace(
                    NativeSpaces.activeSpaceID(),
                    in: NativeSpaces.allSpaces()
                )
            },
            // Liveness only here; the bridge row compares the two.
            .read(copyManagedDisplaySpacesSymbol.resolution, home: home) {
                PrivatePathVerify.managedSpaces(NativeSpaces.allSpaces())
            },
            .read(displayCurrentSpaceSymbol.resolution, home: home) {
                PrivatePathVerify.currentSpaces(
                    { NativeSpaces.currentSpace(displayUUID: $0) },
                    in: NativeSpaces.allSpaces()
                )
            },
        ]
    }

    /// Writes the read-only run looks up and never calls.
    @MainActor
    private static func writeProbes() -> [PrivatePathProbe] {
        [
            disableUpdateSymbol.resolution,
            reenableUpdateSymbol.resolution,
            setConnectionPropertySymbol.resolution,
            transactionCreateSymbol.resolution,
            transactionCommitSymbol.resolution,
            transactionMoveSymbol.resolution,
        ].map { PrivatePathProbe.write($0, home: "SkyLight") }
    }

    @MainActor
    private static func windowProbes(
        _ context: PrivatePathContext
    ) -> [PrivatePathProbe] {
        let home = "SkyLight"
        // Liveness only: no public reading of a window's radius.
        let radius: @MainActor () -> PrivatePathVerdict = {
            guard let own = context.ownWindow() else {
                return PrivatePathVerify.noOwnWindow
            }
            guard let value = windowCornerRadius(own.id) else {
                return .inconclusive(
                    "window \(own.id) answered no radius"
                )
            }
            return .answered("window \(own.id): radius \(Int(value))")
        }
        let radiusSymbols = [
            windowQueryWindowsSymbol.resolution,
            queryResultCopyWindowsSymbol.resolution,
            iteratorGetCountSymbol.resolution,
            iteratorAdvanceSymbol.resolution,
            iteratorGetCornerRadiiSymbol.resolution,
        ]
        return [
            .read(getWindowBoundsSymbol.resolution, home: home) {
                let own = context.ownWindow()
                return PrivatePathVerify.bounds(
                    own.flatMap { windowBounds($0.id) },
                    of: own
                )
            },
            .read(
                copyWindowsWithOptionsAndTagsSymbol.resolution,
                home: home
            ) {
                PrivatePathVerify.census(
                    context.census(),
                    of: context.ownWindow()
                )
            },
            // Liveness only: the bridge row compares the two.
            .read(copySpacesForWindowsSymbol.resolution, home: home) {
                let own = context.ownWindow()
                return PrivatePathVerify.hostedSpace(
                    own.map { context.spaceOfWindow(WindowID($0.id)) }
                        ?? .unavailable,
                    of: own
                )
            },
        ]
            + radiusSymbols.map {
                .read($0, home: home, verify: radius)
            }
    }
}
