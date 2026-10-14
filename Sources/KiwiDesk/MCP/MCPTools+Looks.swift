import Foundation
import KiwiDeskCore

/// The `looks` tool (#1685 ▸ Ruling 2, 6b): the `look.*` verbs as
/// one tool, built by `groupTool`.
extension MCPTools {
    static let looks = "looks"

    /// The command group the tool wraps.
    static let lookGroup = "look"

    static let looksTool = groupTool(
        name: looks,
        group: lookGroup,
        title: "Make and wear KiwiDesk looks",
        lead: "Lists, inspects, wears and saves looks: the colors and "
            + "styling of borders and the KiwiShelf bars. current "
            + "names the setter of each look path; change one with "
            + "\(run), then save it as a new look."
    )
}
