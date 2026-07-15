import Foundation
import Testing

@testable import KiwiDeskCore

private func tempLockPath() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-lock-tests-\(UUID().uuidString)"
        )
        .appendingPathComponent("KiwiDesk.lock").path
}

/// The flock-based bootstrap guard (#196). `flock` contends
/// per open file description, so two locks in one process
/// exercise the same exclusion a second process would hit.
struct SingleInstanceLockTests {
    @Test("First acquire wins and creates the parent dir")
    func firstAcquireWins() {
        let path = tempLockPath()
        let lock = SingleInstanceLock(path: path)
        #expect(lock.acquire())
        #expect(FileManager.default.fileExists(atPath: path))
        lock.release()
    }

    @Test("Second acquire fails while the first holds")
    func secondAcquireFails() {
        let path = tempLockPath()
        let first = SingleInstanceLock(path: path)
        #expect(first.acquire())
        let second = SingleInstanceLock(path: path)
        #expect(!second.acquire())
        first.release()
    }

    @Test("Release frees the lock for the next taker")
    func releaseFrees() {
        let path = tempLockPath()
        let first = SingleInstanceLock(path: path)
        #expect(first.acquire())
        first.release()
        let second = SingleInstanceLock(path: path)
        #expect(second.acquire())
        second.release()
    }

    @Test("An unopenable lock path fails open, not closed")
    func failsOpenOnIOError() {
        // /dev/null is not a directory: createDirectory and
        // open both fail. That is an I/O oddity, not a rival
        // instance — the launch must proceed.
        let lock = SingleInstanceLock(
            path: "/dev/null/nope/KiwiDesk.lock"
        )
        #expect(lock.acquire())
    }

    @Test("Re-acquiring an already-held lock is a no-op")
    func reacquireIsIdempotent() {
        let path = tempLockPath()
        let lock = SingleInstanceLock(path: path)
        #expect(lock.acquire())
        #expect(lock.acquire())
        lock.release()
        let second = SingleInstanceLock(path: path)
        #expect(second.acquire())
        second.release()
    }
}
