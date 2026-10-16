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
            + "define_lens takes table, a JSON object string with "
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

    /// Why an app-wide leaf cannot be kept, and the Settings page
    /// that keeps it: KiwiVision's own, which lists only the lenses
    /// saved there (#2103 ruling 40); General for every other.
    static func appWideHome(_ id: String) -> String {
        let page =
            id.hasPrefix(visionLeaf)
            ? "Settings ▸ KiwiVision" : "Settings ▸ General"
        let tail =
            id.hasPrefix(lensLeaf)
            ? "; define or delete the lens there" : ""
        return "it is app-wide and lasts until a config reload or "
            + "restart; \(page) keeps it\(tail)"
    }
}
