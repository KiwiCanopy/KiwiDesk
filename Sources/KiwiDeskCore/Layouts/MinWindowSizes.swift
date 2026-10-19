import CoreGraphics

/// The stored minimum window size, one per layout that applies a
/// floor (`min_window_size`, #2237). Monocle shows one window at
/// a time and has none. Written whole; read only through
/// `TilingSettings.minWindowSize(for:in:)`.
public struct MinWindowSizes: Sendable, Equatable, Codable {
    /// The layouts that keep a floor — `LayoutMode` without
    /// Monocle (`MinWindowSizesParityTests`).
    public enum Layout: String, CaseIterable, Sendable, Codable {
        case stack
        case grid
        case track
        case bsp
        case scrolling
        case floating

        /// The layout `mode` keeps its floor under, nil for
        /// Monocle.
        public init?(_ mode: LayoutMode) {
            self.init(rawValue: mode.rawValue)
        }

        public var mode: LayoutMode {
            // Every case names a LayoutMode by construction.
            LayoutMode(rawValue: rawValue) ?? .floating
        }
    }

    /// The shipped default on both axes.
    public static let defaultSide: CGFloat = 300

    public var stack: MinSize
    public var grid: MinSize
    public var track: MinSize
    public var bsp: MinSize
    public var scrolling: MinSize
    public var floating: MinSize

    /// Every layout at `size`.
    public init(all size: MinSize = .square(defaultSide)) {
        stack = size
        grid = size
        track = size
        bsp = size
        scrolling = size
        floating = size
    }

    public subscript(layout: Layout) -> MinSize {
        get {
            switch layout {
            case .stack: stack
            case .grid: grid
            case .track: track
            case .bsp: bsp
            case .scrolling: scrolling
            case .floating: floating
            }
        }
        set {
            switch layout {
            case .stack: stack = newValue
            case .grid: grid = newValue
            case .track: track = newValue
            case .bsp: bsp = newValue
            case .scrolling: scrolling = newValue
            case .floating: floating = newValue
            }
        }
    }

    /// Sets `layout`, or every layout where nil — the Lua verb's
    /// and the Settings master's write.
    public mutating func set(_ size: MinSize, for layout: Layout?) {
        guard let layout else {
            self = MinWindowSizes(all: size)
            return
        }
        self[layout] = size
    }

    /// The value every layout holds on `axis`, nil while they
    /// differ — the one "do the layouts agree" verdict the
    /// Settings master, its readout and the Home card read.
    public func shared(_ axis: MinSizeAxis) -> CGFloat? {
        let values = Set(Layout.allCases.map { self[$0][axis] })
        return values.count == 1 ? values.first : nil
    }
}
