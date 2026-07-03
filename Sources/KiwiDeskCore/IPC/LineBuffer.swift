import Foundation

/// Accumulates raw socket bytes and yields complete
/// newline-delimited frames (NDJSON).
public struct LineBuffer: Sendable {
    private var buffer = Data()
    /// Frames larger than this indicate a broken client.
    private let maxLineBytes: Int

    public init(maxLineBytes: Int = 1_048_576) {
        self.maxLineBytes = maxLineBytes
    }

    /// Appends incoming bytes; returns all completed lines
    /// (without the trailing newline).
    public mutating func append(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let raw = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(
                buffer.startIndex...newline
            )
            if let line = String(data: raw, encoding: .utf8),
                !line.isEmpty
            {
                lines.append(line)
            }
        }
        if buffer.count > maxLineBytes {
            buffer.removeAll()
        }
        return lines
    }
}
