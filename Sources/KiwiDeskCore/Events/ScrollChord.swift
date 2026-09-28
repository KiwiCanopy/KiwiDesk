import CoreGraphics

/// The modifiers held with a scroll gesture (#1656, #1519). A
/// scroll matches a chord only on EXACT equality, so ⌃⌥ never
/// answers a ⌃⌥⌘ scroll; caps lock and fn are not modifiers here.
public struct ScrollChord: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = ScrollChord(rawValue: 1 << 0)
    public static let option = ScrollChord(rawValue: 1 << 1)
    public static let command = ScrollChord(rawValue: 1 << 2)
    public static let shift = ScrollChord(rawValue: 1 << 3)

    /// Reads the four modifiers off an event's flags, dropping
    /// every other bit.
    public init(flags: CGEventFlags) {
        var chord: ScrollChord = []
        if flags.contains(.maskControl) { chord.insert(.control) }
        if flags.contains(.maskAlternate) { chord.insert(.option) }
        if flags.contains(.maskCommand) { chord.insert(.command) }
        if flags.contains(.maskShift) { chord.insert(.shift) }
        self = chord
    }
}
