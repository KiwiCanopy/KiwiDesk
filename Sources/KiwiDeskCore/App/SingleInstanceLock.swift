import Foundation

/// Cross-process mutual exclusion for the app bootstrap
/// (issue #196). `flock`-based: the kernel releases the lock
/// when the holding process dies, so a crash never leaves a
/// stale lock that would block relaunch.
///
/// Lives in `KiwiDeskCore` so it is unit-testable with a
/// temporary path, but only the executable's bootstrap ever
/// takes the default lock — core tests never trip it.
public final class SingleInstanceLock {
    private let path: String
    private var descriptor: Int32 = -1

    public init(path: String) {
        self.path = path
    }

    deinit {
        release()
    }

    /// The app's lock file, next to the IPC socket. The socket
    /// itself is no liveness signal: `SocketServer.start()`
    /// removes any existing socket before binding, so a second
    /// instance would silently clobber the first's.
    public nonisolated static var defaultPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                ".config/KiwiDesk/KiwiDesk.lock"
            ).path
    }

    /// Take the lock without blocking. Returns `false` only
    /// when another live process (or another open descriptor
    /// in this one) already holds it.
    ///
    /// I/O failures **fail open** (return `true`): an
    /// unopenable lock file is not a second instance, and
    /// blocking every future launch on a permissions oddity
    /// would be strictly worse than the pre-lock status quo.
    /// `flock` contends per inode, so deleting the config
    /// directory while an instance runs lets a second one
    /// acquire a fresh inode — self-inflicted, accepted.
    public func acquire() -> Bool {
        guard descriptor < 0 else { return true }
        let directory = (path as NSString)
            .deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return true }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            // Only real contention reads as "already
            // running"; any other flock failure fails open.
            let contended = errno == EWOULDBLOCK
            close(fd)
            return !contended
        }
        descriptor = fd
        return true
    }

    /// Drop the lock. Also runs on `deinit`; the kernel drops
    /// it anyway when the process exits.
    public func release() {
        guard descriptor >= 0 else { return }
        flock(descriptor, LOCK_UN)
        close(descriptor)
        descriptor = -1
    }
}
