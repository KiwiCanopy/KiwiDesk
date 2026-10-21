import Foundation
import Testing

@testable import KiwiDeskCore

private func tempLockPath() -> String {
    testTemporaryDirectory
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

    /// An older build updated in place still holds the lock in
    /// the old folder; the new build must see it (#2324).
    @Test("A held legacy lock reads as a running old build")
    func heldLegacyLockRuns() {
        let path = tempLockPath()
        let old = SingleInstanceLock(path: path)
        #expect(old.acquire())
        #expect(SingleInstanceLock.legacyHolderRuns(at: path))
        #expect(FileManager.default.fileExists(atPath: path))
        old.release()
    }

    @Test("A free legacy lock is removed, an absent one ignored")
    func freeLegacyLockIsRemoved() {
        let path = tempLockPath()
        #expect(!SingleInstanceLock.legacyHolderRuns(at: path))
        let old = SingleInstanceLock(path: path)
        #expect(old.acquire())
        old.release()
        #expect(FileManager.default.fileExists(atPath: path))
        #expect(!SingleInstanceLock.legacyHolderRuns(at: path))
        #expect(!FileManager.default.fileExists(atPath: path))
    }
}
