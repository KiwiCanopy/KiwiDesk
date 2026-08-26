/// The SF Symbol that pictures a macOS **Desktop**, wherever the
/// app draws one.
///
/// One copy, because two surfaces assert they agree: the
/// Profiles ▸ Desktops card marks each bindable Desktop with it,
/// and every Desktop keybinding row carries it so a Desktop row
/// reads as a Desktop beside a Space row. Spelled twice, that
/// agreement is a sentence in a doc comment with nothing holding
/// it — the first divergent edit makes the two surfaces picture
/// one concept two ways, and no test would see it.
///
/// Here rather than beside the keybinding catalog because the
/// Profiles card is the older claimant, and a Desktop is a
/// profiles-and-topology concept that the Shortcuts area
/// borrows.
enum DesktopGlyph {
    static let symbol = "square.on.square"
}
