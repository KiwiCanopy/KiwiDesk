import Foundation

/// Cross-process mutual exclusion via kernel flock (#196).
public final class SingleInstanceLock {
    private let path: String
    private var descriptor: Int32 = -1

    public init(path: String) {
        self.path = path
    }

    deinit {
        release()
    }

    /// Default file lock path beside IPC socket (`SocketServer.start()`).
    public nonisolated static var defaultPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                ".config/KiwiDesk/KiwiDesk.lock"
            ).path
    }

    /// Acquires non-blocking flock. Returns false if already held (#196).
    public func acquire() -> Bool {
        guard descriptor < 0 else { return true }
        let directory = (path as NSString)
            .deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else {
            fputs(
                "KiwiDesk: instance lock unopenable at "
                    + "\(path) — proceeding unlocked\n",
                stderr
            )
            return true
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let contended = errno == EWOULDBLOCK
            if !contended {
                fputs(
                    "KiwiDesk: instance lock flock failed "
                        + "(errno \(errno)) — proceeding "
                        + "unlocked\n",
                    stderr
                )
            }
            close(fd)
            return !contended
        }
        descriptor = fd
        return true
    }

    /// Releases flock descriptor.
    public func release() {
        guard descriptor >= 0 else { return }
        flock(descriptor, LOCK_UN)
        close(descriptor)
        descriptor = -1
    }
}
