import CoreServices
import Foundation

/// A running watch over folders; dropping it stops the watch.
@MainActor
protocol SyncWatching: AnyObject {}

/// The live folder watch behind `SyncFollower.makeWatch` (#2324
/// slice 3): one FSEvents stream over the config folder and the
/// sync folder, its events coalesced by the stream's own latency
/// and handed to `fire` on the main queue. FSEvents follows a sync
/// app's renames and an iCloud download as any other write.
@MainActor
final class SyncWatch: SyncWatching {
    private var stream: FSEventStreamRef?
    private let fire: @MainActor () -> Void

    /// Starts a watch over `paths`; nil where the stream refuses.
    static func live(
        _ paths: [URL],
        fire: @escaping @MainActor () -> Void
    ) -> SyncWatching? {
        let watch = SyncWatch(fire: fire)
        return watch.start(paths) ? watch : nil
    }

    private init(fire: @escaping @MainActor () -> Void) {
        self.fire = fire
    }

    private func start(_ paths: [URL]) -> Bool {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watch = Unmanaged<SyncWatch>.fromOpaque(info)
                .takeUnretainedValue()
            MainActor.assumeIsolated { watch.fire() }
        }
        guard
            let stream = FSEventStreamCreate(
                nil,
                callback,
                &context,
                paths.map(\.path) as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                1.0,
                FSEventStreamCreateFlags(
                    kFSEventStreamCreateFlagFileEvents
                        | kFSEventStreamCreateFlagNoDefer
                )
            )
        else { return false }
        FSEventStreamSetDispatchQueue(stream, .main)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return false
        }
        self.stream = stream
        return true
    }

    isolated deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}
