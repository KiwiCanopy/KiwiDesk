import Foundation

extension KiwiShelf {
    /// How the bars read while a window is maximized (#3346): both
    /// read Hidden, and Auto adds a band at each bar's edge that
    /// brings it in over the window. Two cases, so `always` is
    /// refused at the decode.
    public enum MaximizedVisibility: String, Sendable, Codable,
        CaseIterable
    {
        case auto
        case hidden
    }
}
