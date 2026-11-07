import Foundation

/// In-memory source caching and file enumeration for SourceScan.
/// Thread-safe: test suites running concurrently in swift-testing
/// share these caches without re-reading or re-stripping files from disk.
extension SourceScan {
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var sourcesCache: [URL: [URL]] = [:]
    nonisolated(unsafe) private static var rawFileCache: [URL: String] = [:]
    nonisolated(unsafe) private static var strippedCache: [StripKey: String] =
        [:]
    nonisolated(unsafe) private static var blankedCache: [URL: String] = [:]
    nonisolated(unsafe) private static var stripLocks: [StripKey: NSLock] = [:]
    nonisolated(unsafe) private static var blankLocks: [URL: NSLock] = [:]

    /// Reads raw string contents of `url`, cached in-memory
    /// across test suites.
    static func rawSource(at url: URL) throws -> String {
        cacheLock.lock()
        if let cached = rawFileCache[url] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        let raw = try String(contentsOf: url, encoding: .utf8)
        cacheLock.lock()
        rawFileCache[url] = raw
        cacheLock.unlock()
        return raw
    }

    /// `url` with comments stripped, through `memoizedStrip`.
    static func strippedSource(at url: URL) throws -> String {
        stripComments(try rawSource(at: url))
    }

    /// One strip per distinct text passed in, single-flight (#1868).
    /// Keyed by `String` equality, so canonically equal texts share
    /// an answer.
    static func memoizedStrip(_ source: String) -> String {
        let key = StripKey(source)
        let textLock: NSLock = cacheLock.withLock {
            if let lock = stripLocks[key] { return lock }
            let lock = NSLock()
            stripLocks[key] = lock
            return lock
        }
        textLock.lock()
        defer { textLock.unlock() }
        if let cached = cacheLock.withLock({ strippedCache[key] }) {
            return cached
        }
        let result = stripped(Array(source))
        cacheLock.withLock { strippedCache[key] = result }
        return result
    }

    /// A text with its hash precomputed, so `cacheLock` never hashes
    /// a whole text.
    private struct StripKey: Hashable {
        let text: String
        let textHash: Int

        init(_ text: String) {
            self.text = text
            textHash = text.hashValue
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(textHash)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.textHash == rhs.textHash && lhs.text == rhs.text
        }
    }

    /// `url` with comments AND literals blanked, cached across
    /// suites by file (#1894). Single-flight per file.
    static func blankedSource(at url: URL) throws -> String {
        let fileLock: NSLock = cacheLock.withLock {
            if let lock = blankLocks[url] { return lock }
            let lock = NSLock()
            blankLocks[url] = lock
            return lock
        }
        fileLock.lock()
        defer { fileLock.unlock() }
        if let cached = cacheLock.withLock({ blankedCache[url] }) {
            return cached
        }
        let blanked = blankingCommentsAndLiterals(try rawSource(at: url))
        cacheLock.withLock { blankedCache[url] = blanked }
        return blanked
    }

    /// Every target directory under `Sources/` or `Tests/`,
    /// discovered rather than listed — a third target added to
    /// `Package.swift` is otherwise scanned by nothing, and a
    /// guard's whole argument is about the code not yet written
    /// (the test-tree twins used to hand-list the two test
    /// targets three times over). `TargetTreeParityTests` holds
    /// the answer against `Package.swift`'s own `path:` lines, so
    /// an empty or partial walk reds there rather than passing
    /// every adopter as "no strays".
    static func targetTrees(
        under parent: URL
    ) -> [URL] {
        let entries = try? FileManager.default
            .contentsOfDirectory(
                at: parent,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
        return (entries ?? [])
            .filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?
                    .isDirectory == true
            }
            .sorted { $0.path < $1.path }
    }

    /// Enumerates all `.swift` files under `directory`, cached in-memory.
    static func swiftSources(
        under directory: URL
    ) throws -> [URL] {
        cacheLock.lock()
        if let cached = sourcesCache[directory] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        )
        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            if item.pathExtension == "swift" {
                files.append(item)
            }
        }
        cacheLock.lock()
        sourcesCache[directory] = files
        cacheLock.unlock()
        return files
    }
}

extension SourceScan {
    /// The repo root, derived from a test file's own path.
    static func repoRoot(from filePath: String) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()  // KiwiDeskGuiTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }
}

extension String {
    /// Non-overlapping occurrences of `needle`.
    func occurrences(of needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var total = 0
        var cursor = startIndex
        while let found = range(
            of: needle,
            range: cursor..<endIndex
        ) {
            total += 1
            cursor = found.upperBound
        }
        return total
    }
}
