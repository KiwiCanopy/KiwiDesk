import Foundation

/// The bridge's operations as `self_test` probes them (#1889):
/// one row per `Operation`, so a new operation is probed by being
/// declared. A read is dispatched and checked against the C
/// reader; a write is looked up and never dispatched.
extension WMBridge {
    static func selfTestProbes(
        _ context: PrivatePathContext
    ) -> [PrivatePathProbe] {
        Operation.allCases.map { operation in
            let resolved: @MainActor () -> Bool = {
                resolve(operation) != nil
            }
            guard operation.isRead else {
                return .write(
                    operation.rawValue,
                    kind: .bridgeClass,
                    home: "WMBridge",
                    resolved: resolved
                )
            }
            return .read(
                operation.rawValue,
                kind: .bridgeClass,
                home: "WMBridge",
                resolved: resolved,
                verify: { verify(operation, context) }
            )
        }
    }

    private static func verify(
        _ operation: Operation,
        _ context: PrivatePathContext
    ) -> PrivatePathVerdict {
        switch operation {
        case .copyManagedDisplaySpaces:
            return PrivatePathVerify.bridgeSpaces(
                managedDisplaySpaces(),
                against: NativeSpaces.allSpaces()
            )
        case .spaceCopyName, .spaceCopyValues:
            guard let active = NativeSpaces.activeSpaceID() else {
                return .inconclusive("no active Space to read")
            }
            return operation == .spaceCopyName
                ? PrivatePathVerify.answered(
                    name(of: active),
                    "Space \(active) answered its name"
                )
                : PrivatePathVerify.answered(
                    values(of: active),
                    "Space \(active) answered its values"
                )
        case .copySpacesForWindows:
            guard let own = context.ownWindow() else {
                return PrivatePathVerify.noOwnWindow
            }
            let id = WindowID(own.id)
            return PrivatePathVerify.bridgeWindowSpaces(
                spaces(for: [id]),
                against: context.spaceOfWindow(id),
                of: own
            )
        default:
            return .unexercised
        }
    }
}
