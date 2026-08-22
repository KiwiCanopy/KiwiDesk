import Foundation

/// In-memory source caching and file enumeration for SourceScan.
/// Thread-safe: test suites running concurrently in swift-testing
/// share these caches without re-reading or re-stripping files from disk.
extension SourceScan {
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var sourcesCache: [URL: [URL]] = [:]
    nonisolated(unsafe) private static var rawFileCache: [URL: String] = [:]
    nonisolated(unsafe) private static var strippedCache: [URL: String] = [:]

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

    /// Reads `url`, strips comments, and caches the result so
    /// subsequent scans over the same file reuse the parsed representation.
    static func strippedSource(at url: URL) throws -> String {
        cacheLock.lock()
        if let cached = strippedCache[url] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        let raw = try rawSource(at: url)
        let stripped = stripComments(raw)
        cacheLock.lock()
        strippedCache[url] = stripped
        cacheLock.unlock()
        return stripped
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
