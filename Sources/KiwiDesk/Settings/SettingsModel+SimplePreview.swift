import KiwiDeskCore

/// What the pointer previews on Simple's Space cards (#2777).
enum SimplePreviewHover: Equatable {
    /// A bundled look, by name, painted over the draft.
    case look(String)
}

/// Simple's Space pictures (#2777): one reading of which look they
/// wear.
extension SettingsModel {
    /// The hover the pictures are drawing, nil when the hovered
    /// look is gone.
    var simplePreviewHover: SimplePreviewHover? {
        switch nav.simpleHover {
        case .look(let name) where hoveredLook(name) != nil:
            return .look(name)
        default:
            return nil
        }
    }

    /// The pointer entered or left `subject`; a leave clears only
    /// its own hover, since the next enter can arrive first.
    func hoverSimple(_ subject: SimplePreviewHover, inside: Bool) {
        if inside {
            nav.simpleHover = subject
        } else if nav.simpleHover == subject {
            nav.simpleHover = nil
        }
    }

    /// The draft as the preview draws it: with a hovered look
    /// painted on, its colors included.
    var simplePreviewSettings: TilingSettings {
        guard case .look(let name) = simplePreviewHover,
            let look = hoveredLook(name)
        else { return config.settings }
        return look.painted(over: config.settings)
    }

    private func hoveredLook(_ name: String) -> ShelfLook? {
        core.bundledLooks.first { $0.name == name }
    }
}
