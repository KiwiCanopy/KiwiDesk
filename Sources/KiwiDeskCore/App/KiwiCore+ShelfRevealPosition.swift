import AppKit

extension KiwiCore.HidingShelves {
    /// A hidden Space Bar's place for VoiceOver: the current Space's
    /// place from 1 and the Space count, nil without a Space shown.
    static func spacePosition(
        _ items: [SpaceBarOverlay.Item]?
    ) -> ShelfHandleSpec.Position? {
        let spaces = (items ?? []).filter { $0.space != nil }
        return spaces.firstIndex(where: \.active).map {
            .init(index: $0 + 1, count: spaces.count)
        }
    }
}
