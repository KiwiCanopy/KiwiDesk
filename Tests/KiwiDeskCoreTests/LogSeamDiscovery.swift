import Foundation

@testable import KiwiDeskCore

/// Runtime discovery of `onLog` seams over the live `KiwiCore`
/// object graph, for `LogSeamProbeTests` (#625).
///
/// **Why the call goes through a protocol.** The obvious shape —
/// take `child.value` from a `Mirror` and cast it to
/// `@MainActor (String) -> Void` — compiles, and the cast even
/// succeeds. Calling the result does not work: `Mirror`'s box for
/// a **function-typed** stored property yields a value that
/// segfaults on call, or delivers a corrupted argument (a probe
/// sending `"plain probe"` observed
/// `"°㒫\u{01}\0\0\0obe"` arrive). Casting to the exact dynamic
/// type, `@Sendable` included, does not help, and it is not
/// `@MainActor`-specific. The same cast out of a plain `Any` that
/// never went through `Mirror` is correct, so the defect is the
/// reflection box, not the isolation. Measured on Swift 6.3.3 /
/// arm64.
///
/// A guard built the obvious way would therefore not merely be
/// broken — it could be **green while proving nothing**, since an
/// assertion phrased as "the sink received one line" is satisfied
/// by garbage. So `Mirror` is only ever asked for the **object**,
/// which it boxes soundly, and every call goes through
/// `LogSeamOwner.onLog`, a real typed accessor.
@MainActor
protocol LogSeamOwner: AnyObject {
    var onLog: @MainActor (String) -> Void { get set }
}

extension AnimationEngine: LogSeamOwner {}
extension BorderManager: LogSeamOwner {}
extension CrashRecovery: LogSeamOwner {}
extension EventBus: LogSeamOwner {}
extension ExecLauncher: LogSeamOwner {}
extension KeybindingManager: LogSeamOwner {}
extension ProfileManager: LogSeamOwner {}
extension SocketServer: LogSeamOwner {}
// `KiwiCore` deliberately does not conform. It is the sink these
// forward *into*, not a seam, and it is exempted by identity
// below rather than by name — see `SeamWalk.exempt`.

/// One seam found on the live graph.
struct FoundSeam {
    /// `core.tiler.animation`, for a message that can be acted on.
    let path: String
    let owner: LogSeamOwner
}

/// A depth-first walk of the `KiwiCore` graph that collects seam
/// owners by **instance**.
///
/// Terminating by an `ObjectIdentifier` visited set rather than by
/// a depth cap: the graph holds back-references (`socket.bus`), so
/// identity is what actually stops it. `maxDepth` is a fail-shut
/// backstop only — reaching it is reported as a gap rather than
/// silently truncating the walk, because a truncated walk is a
/// guard that passes for the wrong reason.
@MainActor
struct SeamWalk {
    /// Deep enough for the shipped graph with room to spare, low
    /// enough that a cycle the visited set somehow missed is
    /// reported instead of hanging.
    static let maxDepth = 12

    private(set) var seams: [FoundSeam] = []
    /// Objects that declare an `onLog` but were not conformed to
    /// `LogSeamOwner` in this file — the one hand-written list
    /// here, kept honest by being checked rather than trusted.
    private(set) var unconformed: [String] = []
    private(set) var gaps: [String] = []

    private var visited: Set<ObjectIdentifier> = []
    /// Excluded by identity, not by type name: the sink object we
    /// started from. A second `KiwiCore` reachable from the graph
    /// would still be walked.
    private let exempt: ObjectIdentifier

    init(root: AnyObject) {
        exempt = ObjectIdentifier(root)
    }

    static func over(_ root: AnyObject) -> SeamWalk {
        var walk = SeamWalk(root: root)
        walk.descend(root, path: "core", depth: 0)
        return walk
    }

    private mutating func descend(
        _ value: Any,
        path: String,
        depth: Int
    ) {
        guard depth <= Self.maxDepth else {
            gaps.append(
                "the walk hit its \(Self.maxDepth)-level depth "
                    + "backstop at \(path), so the graph below "
                    + "it was never searched"
            )
            return
        }
        let mirror = Mirror(reflecting: value)

        if let object = value as AnyObject?,
            mirror.displayStyle == .class
        {
            let id = ObjectIdentifier(object)
            guard !visited.contains(id) else { return }
            visited.insert(id)
            record(object, mirror: mirror, path: path)
        }

        for child in mirror.children {
            // An unlabelled child is an Optional's payload or a
            // collection element; it inherits its parent's path.
            let childPath =
                child.label.map { "\(path).\($0)" } ?? path
            guard child.label != "onLog" else { continue }
            descend(child.value, path: childPath, depth: depth + 1)
        }
    }

    /// Classify one visited object: a seam owner to probe, a seam
    /// owner that was never conformed, or neither.
    private mutating func record(
        _ object: AnyObject,
        mirror: Mirror,
        path: String
    ) {
        let declaresSeam = mirror.children.contains {
            $0.label == "onLog"
        }
        guard declaresSeam, ObjectIdentifier(object) != exempt
        else { return }

        if let owner = object as? LogSeamOwner {
            seams.append(FoundSeam(path: path, owner: owner))
        } else {
            unconformed.append(
                "\(path) (\(type(of: object)))"
            )
        }
    }
}
