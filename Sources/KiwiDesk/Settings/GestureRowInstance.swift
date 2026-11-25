import KiwiDeskCore

/// A gesture diff row's instance (#3183): the one key it names, or
/// a move's two — the key a binding left and the key it took, which
/// its ↺ takes back together — each on its layer (#3535). Minted
/// and parsed here alone, as a rule-list row's `ListEntryInstance`
/// is.
enum GestureRowInstance: Equatable {
    case key(LayerGestureKey)
    case move(from: LayerGestureKey, to: LayerGestureKey)

    /// No key spelling holds it, nor a layer name a user types.
    private static let separator: Character = "\u{1E}"

    var spelling: String {
        switch self {
        case .key(let key): key.spelling
        case .move(let from, let to):
            from.spelling + String(Self.separator) + to.spelling
        }
    }

    /// Every key the row names.
    var keys: [LayerGestureKey] {
        switch self {
        case .key(let key): [key]
        case .move(let from, let to): [from, to]
        }
    }

    init?(instance: String) {
        let parts = instance.split(separator: Self.separator)
            .compactMap { LayerGestureKey(spelling: String($0)) }
        switch parts.count {
        case 1: self = .key(parts[0])
        case 2: self = .move(from: parts[0], to: parts[1])
        default: return nil
        }
    }
}
