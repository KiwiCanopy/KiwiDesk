import Foundation

extension Space {
    /// Clears this Space's SIZING — what `resize` accumulates in
    /// the Space: the weights and the run sizes — and nothing
    /// structural (#764). The one statement of which stored
    /// properties are sizes: `SpaceSizingCensusTests` classifies
    /// every property as cleared here or named structure, so a
    /// new store cannot join unclassified. The per-Desktop
    /// session ratios live outside the Space (#2921) and are
    /// cleared beside this by `reset_layout_sizing`.
    public mutating func resetSizing() {
        stackWeights = [:]
        runSizes = [:]
        trackWeights = [:]
    }
}
