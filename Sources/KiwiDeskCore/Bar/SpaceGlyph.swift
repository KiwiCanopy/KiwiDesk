/// What a bar chip shows for a Space's or a layer's identity
/// (#1169): an SF Symbol, or text — tinted like the state (digits,
/// a name's cut, a plain character) or untinted (an emoji takes no
/// template tint). Public so the Bars preview draws Core's verdict
/// rather than a reading of its own (#1538, #702).
public enum SpaceGlyph: Equatable {
    case symbol(String)
    case text(String, tinted: Bool)
}
