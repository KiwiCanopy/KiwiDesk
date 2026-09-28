import Foundation
import Testing

/// **Content leaves a glass only through `GlassPlate`** (#1730).
///
/// Hosting turns the content's
/// `translatesAutoresizingMaskIntoConstraints` off, and only
/// `GlassPlate.release` turns it back on; a raw `contentView =`
/// write on a glass hands a view back that lays out in the corner.
/// `GlassHandBackTests` holds what `release` does; this suite holds
/// that nothing reaches past it, in either Sources tree.
@Suite("Glass content writes have one home (#1730)")
struct GlassHandBackSeamTests {
    private static let home = "GlassPlate.swift"
    private static let glassType = "NSGlassEffectView"

    /// Files outside the home whose glass-typed `contentView =`
    /// writes are ruled, each naming why. Empty: a panel's or a
    /// window's `contentView` (`MonocleFlipOverlay`'s
    /// `panel?.contentView = nil`) is not a glass, and the needle
    /// below asks the receiver's TYPE, so it never sees them.
    private static let allowed: [String: String] = [:]

    /// A `contentView` assignment (not `==`, not `!==`); group 1
    /// is the receiver text on that line.
    private static let write = try! NSRegularExpression(
        pattern: #"([^\n]*?)\??\.contentView\s*=(?!=)"#
    )

    /// Names bound to the glass type in the file: a cast
    /// (`let g = v as? NSGlassEffectView`) or an annotation
    /// (`g: NSGlassEffectView`).
    private static let binding = try! NSRegularExpression(
        pattern: #"(\w+)\s*(?:=[^\n]*?\bas[?!]\s*|:\s*)"#
            + #"NSGlassEffectView\b"#
    )

    /// The glass-typed `contentView` writes in `source`: the
    /// receiver spells the glass type itself, or ends in a name the
    /// file bound to it.
    static func glassWrites(in source: String) -> [String] {
        let ns = source as NSString
        let all = NSRange(location: 0, length: ns.length)
        let bound = Set(
            binding.matches(in: source, range: all).map {
                ns.substring(with: $0.range(at: 1))
            }
        )
        return write.matches(in: source, range: all).compactMap {
            let receiver = ns.substring(with: $0.range(at: 1))
            if receiver.contains(glassType) {
                return receiver.trimmingCharacters(in: .whitespaces)
            }
            let tail = receiver.reversed().prefix {
                $0.isLetter || $0.isNumber || $0 == "_"
            }
            let name = String(tail.reversed())
            return bound.contains(name) ? name : nil
        }
    }

    @Test("no glass contentView write outside GlassPlate")
    func contentWritesHaveOneHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        var scanned = 0
        var anchored = false
        var strays: [String] = []
        for file in try SourceScan.swiftSources(under: root) {
            scanned += 1
            let name = file.lastPathComponent
            let writes = Self.glassWrites(
                in: try SourceScan.strippedSource(at: file)
            )
            guard !writes.isEmpty else { continue }
            if name == Self.home {
                anchored = true
            } else if Self.allowed[name] == nil {
                strays.append("\(name): \(writes)")
            }
        }
        // A floor over both trees, never the live count: an empty
        // walk would pass as "no strays".
        #expect(scanned >= 500, "scanned \(scanned) files")
        // The needle must still see the home's own writes, or the
        // clause below empties in silence.
        #expect(anchored, "\(Self.home) shows no glass write")
        #expect(strays.isEmpty, "\(strays)")
    }

    @Test("the needle sees a cast write and skips a panel's")
    func needleShape() {
        #expect(
            Self.glassWrites(
                in: "(glass as? NSGlassEffectView)?.contentView = nil"
            ).count == 1
        )
        #expect(
            Self.glassWrites(in: "panel?.contentView = nil").isEmpty
        )
        #expect(
            Self.glassWrites(
                in: "if glass.contentView !== content {}"
            ).isEmpty
        )
    }
}
