import Foundation
import KiwiDeskCore

/// The `kiwivision` tool (#1685 ▸ Ruling 2, #2103): the
/// `kiwivision.*` verbs as one tool, built by `groupTool`.
extension MCPTools {
    static let kiwiVision = "kiwivision"

    /// The command group the tool wraps.
    static let kiwiVisionGroup = "kiwivision"

    /// The lens table's keys are read off `VisionLens`' own coding,
    /// so the model is never told a key `define_lens` does not read.
    static let kiwiVisionSpec = GroupToolSpec(
        name: kiwiVision,
        group: kiwiVisionGroup,
        title: "Focus with KiwiVision and its lenses",
        lead: "KiwiVision dims and blurs every screen around the "
            + "focused window; a lens is a named KiwiVision that also "
            + "keeps its apps clear. current reads what is on, the "
            + "settings and each lens with why it cannot turn on. "
            + "define_lens takes lens as a JSON object string with "
            + "the keys " + VisionLens.tableKeys.joined(separator: ", ")
            + "; an app is a bundle_id \(getState) lists. "
            + "set_never_dimmed replaces the whole list with one app; "
            + "send several with \(run)."
    )
}

extension MCPWording {
    /// The keep document's KiwiVision group (`gui.json`'s
    /// `kiwivision`), and its lens list inside it.
    static let visionLeaf = "/app_wide/kiwivision/"
    static let lensLeaf = visionLeaf + "lenses"

    /// Where Settings keeps an app-wide leaf `keep` cannot: a
    /// KiwiVision value on its own page, a lens only by making it
    /// there, since that page lists the saved lenses alone (#2103
    /// ruling 40); every other on General.
    static func appWideHome(_ id: String) -> String {
        if id.hasPrefix(lensLeaf) {
            return "a lens a command defines or deletes lasts until a "
                + "config reload or restart, and Settings ▸ KiwiVision "
                + "shows only saved lenses; make it there to keep it"
        }
        if id.hasPrefix(visionLeaf) {
            return "it is app-wide and lasts until a config reload or "
                + "restart; Settings ▸ KiwiVision keeps it"
        }
        return "it is app-wide and lasts until KiwiDesk restarts; "
            + "Settings ▸ General keeps it"
    }
}
