import KiwiDeskCore

extension SettingsModel {
    /// Why the Key sequences card cannot edit `layer`'s sequences on
    /// this page, nil where it can (#1871, #3124). A sequence has no
    /// key in the reach table, so a stored page's Save drops it, and
    /// the loaded profile's own copy would be saved into the shared
    /// rows while its override kept the old one.
    func sequenceEditBlock(in layer: String) -> SequenceEditBlock? {
        guard reachIsLoaded else { return .storedPage }
        guard let page = reachLoaded,
            let own = encodedReach?.storedKeyOverrides[page],
            own.layers.contains(where: {
                $0.name == layer && !$0.sequences.isEmpty
            })
        else { return nil }
        return .profileOwnsSequences
    }
}

/// What keeps the Key sequences card greyed (#3124).
enum SequenceEditBlock: Equatable {
    /// A stored profile's page.
    case storedPage
    /// The loaded profile keeps its own sequences in the layer.
    case profileOwnsSequences
}
