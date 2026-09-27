@testable import KiwiDeskCore

/// One id-keyed container reflection found: the stored-property
/// path that reached it (`[]` marks a dictionary value) and its
/// `String(describing:)` rendering.
struct IDContainer {
    let path: String
    let rendered: String
}

/// Every non-empty dictionary, set, or array whose keys/elements
/// are ids (`WindowID` by default), reachable by recursing
/// structs, classes, optionals, and dictionary *values* (so the
/// per-space maps inside `WorkspaceManager` are found). Empty
/// containers are skipped — their element type cannot be read.
/// The ONE walker: `WindowRekeyParityTests` (#308) and
/// `SnapshotCarryCensusTests` (#930) both read it, so a container
/// shape one learns to see, the other sees too.
func idContainers(
    _ value: Any,
    path: String = "",
    depth: Int = 8,
    isID: (Any) -> Bool = { $0 is WindowID }
) -> [IDContainer] {
    guard depth > 0 else { return [] }
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .dictionary:
        var found: [IDContainer] = []
        if let first = mirror.children.first,
            let key = Mirror(reflecting: first.value).children.first,
            isID(key.value)
        {
            found.append(
                IDContainer(path: path, rendered: String(describing: value))
            )
        }
        for child in mirror.children {
            let pair = Array(Mirror(reflecting: child.value).children)
            if let entryValue = pair.last?.value {
                found += idContainers(
                    entryValue,
                    path: path + "[]",
                    depth: depth - 1,
                    isID: isID
                )
            }
        }
        return found
    case .set, .collection:
        guard let first = mirror.children.first, isID(first.value)
        else { return [] }
        return [IDContainer(path: path, rendered: String(describing: value))]
    case .optional, .struct, .class, .tuple, .enum:
        return mirror.children.flatMap { child in
            let label = child.label ?? "_"
            let next =
                mirror.displayStyle == .optional
                ? path : (path.isEmpty ? label : path + "." + label)
            return idContainers(
                child.value,
                path: next,
                depth: depth - 1,
                isID: isID
            )
        }
    default:
        return []
    }
}
