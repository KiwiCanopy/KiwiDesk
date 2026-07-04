import Foundation

/// monocle.* sub-API: orientation (which focus axis cycles
/// through the windows) and the indicator bar listing them.
extension KiwiCore {
    func monocleCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "monocle.set_orientation":
            guard let raw = args.first?.stringValue,
                let orientation =
                    MonocleParams.Orientation(rawValue: raw)
            else {
                return .fail("expected horizontal|vertical")
            }
            tiler.settings.monocle.orientation = orientation
            warnOnBarPositionMismatch()
        case "monocle.set_bar_enabled":
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.settings.monocle.bar.enabled = enabled
        case "monocle.set_bar_position":
            guard let raw = args.first?.stringValue,
                let position =
                    MonocleParams.Bar.Position(rawValue: raw)
            else {
                return .fail("expected top|bottom|left|right")
            }
            tiler.settings.monocle.bar.position = position
            warnOnBarPositionMismatch()
        case "monocle.set_bar_style":
            guard let raw = args.first?.stringValue,
                let style =
                    MonocleParams.Bar.Style(rawValue: raw)
            else {
                return .fail(
                    "expected pills|segments|underline"
                )
            }
            tiler.settings.monocle.bar.style = style
        case "monocle.set_bar_active_style":
            guard let raw = args.first?.stringValue,
                let style =
                    MonocleParams.Bar.ActiveStyle(
                        rawValue: raw
                    )
            else {
                return .fail("expected highlight|gap")
            }
            tiler.settings.monocle.bar.activeStyle = style
        case "monocle.set_bar_content":
            guard let raw = args.first?.stringValue,
                let content =
                    MonocleParams.Bar.Content(rawValue: raw)
            else {
                return .fail(
                    "expected icon|name|icon_and_name"
                )
            }
            tiler.settings.monocle.bar.content = content
        default:
            return setMonocleNumber(command, args)
                ?? setMonocleColor(command, args)
        }
        return .ok()
    }

    /// The pt-valued setters, all clamped at 0. Nil when the
    /// command isn't one of them (colors come next).
    private func setMonocleNumber(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse? {
        let numbers:
            [String: WritableKeyPath<
                MonocleParams, CGFloat
            >] = [
                "monocle.set_bar_thickness": \.bar.thickness,
                "monocle.set_bar_item_size": \.bar.itemSize,
                "monocle.set_bar_item_gap": \.bar.itemGap,
                "monocle.set_bar_font_size": \.bar.fontSize,
                "monocle.set_bar_corner_radius":
                    \.bar.cornerRadius,
            ]
        guard let keyPath = numbers[command] else {
            return nil
        }
        guard let value = args.first?.numberValue else {
            return .fail("expected a length (pt)")
        }
        tiler.settings.monocle[keyPath: keyPath] =
            max(0, value)
        return .ok()
    }

    private func setMonocleColor(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        let colors:
            [String: WritableKeyPath<
                MonocleParams, String
            >] = [
                "monocle.set_bar_text_color": \.bar.textColor,
                "monocle.set_bar_box_color": \.bar.boxColor,
                "monocle.set_bar_active_text_color":
                    \.bar.activeTextColor,
                "monocle.set_bar_active_box_color":
                    \.bar.activeBoxColor,
                "monocle.set_bar_highlight_color":
                    \.bar.highlightColor,
                "monocle.set_bar_hover_color": \.bar.hoverColor,
                "monocle.set_bar_hover_text_color":
                    \.bar.hoverTextColor,
                "monocle.set_bar_background_color":
                    \.bar.backgroundColor,
            ]
        guard let keyPath = colors[command] else {
            return .fail("unknown command: \(command)")
        }
        guard let hex = args.first?.stringValue,
            DragVisual.parseHex(hex) != nil
        else {
            return .fail("expected #RRGGBB or #RRGGBBAA")
        }
        tiler.settings.monocle[keyPath: keyPath] = hex
        return .ok()
    }

    /// Cycles or reorders along the monocle orientation axis.
    ///
    /// `focus`/`swap` in the orientation's directions step
    /// through the space's flat window order, wrapping at the
    /// ends. Nil for cross-axis directions and for a floating
    /// focused window — those keep the geometric navigation
    /// (which can still reach other monitors).
    func monocleCycle(
        _ direction: Direction,
        space: Space,
        focused: WindowID,
        swapping: Bool
    ) -> CommandResponse? {
        let horizontal =
            tiler.settings.monocle.orientation == .horizontal
        let step: Int
        switch direction {
        case .left where horizontal: step = -1
        case .right where horizontal: step = 1
        case .up where !horizontal: step = -1
        case .down where !horizontal: step = 1
        default: return nil
        }
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard let index = tiled.firstIndex(of: focused)
        else { return nil }
        guard tiled.count > 1 else { return .ok() }
        let target =
            tiled[
                (index + step + tiled.count) % tiled.count
            ]
        if swapping {
            state.workspaces.withSpace(space.id) {
                $0.swap(focused, target)
            }
            retile()
        } else {
            focusWindow(target)
        }
        return .ok()
    }

    /// A bar position that doesn't fit the orientation is
    /// kept in the settings but resolved to the orientation's
    /// default edge — warn so the user isn't left guessing.
    private func warnOnBarPositionMismatch() {
        let monocle = tiler.settings.monocle
        guard
            monocle.bar.position
                != monocle.resolvedBarPosition
        else { return }
        onLog(
            "monocle: bar position '"
                + monocle.bar.position.rawValue
                + "' doesn't fit \(monocle.orientation.rawValue)"
                + " orientation — using '"
                + monocle.resolvedBarPosition.rawValue + "'"
        )
    }
}
