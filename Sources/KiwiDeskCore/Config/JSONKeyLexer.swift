import Foundation

/// A key-and-scalar index over JSON text for a surgical edit
/// (#3236): each object member whose value is a scalar, with the
/// value's byte range and the object it belongs to. No validation —
/// `ConfigMigration.surgicallyApplying` re-parses whatever an edit
/// makes and keeps it only when it matches the walk.
enum JSONKeyLexer {
    struct Entry: Equatable {
        /// The key as written between its quotes, escapes kept.
        let key: String
        /// The scalar literal as written: `0`, `true`, `"text"`.
        let value: String
        /// The literal's UTF-8 byte range in the text.
        let valueRange: Range<Int>
        /// The byte offset of the owning object's `{`.
        let object: Int
        /// The byte offset of the key's opening quote.
        var keyStart = 0
    }

    private struct Frame {
        let isObject: Bool
        let open: Int
        var expectsKey: Bool
    }

    static func entries(in text: String) -> [Entry] {
        let bytes = Array(text.utf8)
        var stack: [Frame] = []
        var pendingKey: String?
        var pendingKeyStart = 0
        var out: [Entry] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            switch byte {
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                stack.append(
                    Frame(
                        isObject: byte == UInt8(ascii: "{"),
                        open: index,
                        expectsKey: true
                    )
                )
                pendingKey = nil
                index += 1
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                _ = stack.popLast()
                index += 1
            case UInt8(ascii: ","):
                if let top = stack.indices.last, stack[top].isObject {
                    stack[top].expectsKey = true
                }
                index += 1
            case UInt8(ascii: "\""):
                let end = stringEnd(bytes, from: index)
                let literal = String(
                    decoding: bytes[index..<end],
                    as: UTF8.self
                )
                if let top = stack.indices.last, stack[top].isObject,
                    stack[top].expectsKey
                {
                    pendingKey = String(literal.dropFirst().dropLast())
                    pendingKeyStart = index
                    stack[top].expectsKey = false
                } else if let key = pendingKey, let top = stack.last {
                    out.append(
                        Entry(
                            key: key,
                            value: literal,
                            valueRange: index..<end,
                            object: top.open,
                            keyStart: pendingKeyStart
                        )
                    )
                    pendingKey = nil
                }
                index = end
            case UInt8(ascii: " "), UInt8(ascii: "\n"), UInt8(ascii: "\t"),
                UInt8(ascii: "\r"), UInt8(ascii: ":"):
                index += 1
            default:
                let end = scalarEnd(bytes, from: index)
                if let key = pendingKey, let top = stack.last {
                    out.append(
                        Entry(
                            key: key,
                            value: String(
                                decoding: bytes[index..<end],
                                as: UTF8.self
                            ),
                            valueRange: index..<end,
                            object: top.open,
                            keyStart: pendingKeyStart
                        )
                    )
                    pendingKey = nil
                }
                index = max(end, index + 1)
            }
        }
        return out
    }

    /// The offset just past the string opening at `start`.
    private static func stringEnd(_ bytes: [UInt8], from start: Int) -> Int {
        var index = start + 1
        while index < bytes.count {
            switch bytes[index] {
            case UInt8(ascii: "\\"): index += 2
            case UInt8(ascii: "\""): return index + 1
            default: index += 1
            }
        }
        return bytes.count
    }

    /// The offset just past the bare scalar starting at `start`.
    private static func scalarEnd(_ bytes: [UInt8], from start: Int) -> Int {
        let stops: Set<UInt8> = Set(",}] \n\t\r".utf8)
        var index = start
        while index < bytes.count, !stops.contains(bytes[index]) {
            index += 1
        }
        return index
    }
}
