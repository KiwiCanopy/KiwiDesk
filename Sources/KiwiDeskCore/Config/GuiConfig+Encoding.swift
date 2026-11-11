import Foundation

/// `gui.json`'s encoder, split from `GuiConfig.swift` at the file
/// ceiling; `init(from:)` beside the stored fields is its pair.
extension GuiConfig {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )
        try container.encode(format, forKey: .format)
        try container.encode(spaces, forKey: .spaces)
        try container.encode(appRules, forKey: .appRules)
        try container.encode(floatRules, forKey: .floatRules)
        try container.encode(ignoreRules, forKey: .ignoreRules)
        try container.encode(layers, forKey: .layers)
        try container.encode(scrollGesture, forKey: .scrollGesture)
        if !gesture.isEmpty {
            try container.encode(gesture, forKey: .gesture)
        }
        try container.encode(spaceHistory, forKey: .spaceHistory)
        try container.encode(modeCycle, forKey: .modeCycle)
        try container.encode(focusWrap, forKey: .focusWrap)
        try container.encode(
            floatAutomatically,
            forKey: .floatAutomatically
        )
        try container.encode(tileRules, forKey: .tileRules)
        try container.encode(
            shortcutBase,
            forKey: .shortcutBase
        )
        if let appWide {
            try container.encode(appWide.refusal, forKey: .refusal)
            try container.encode(appWide.quit, forKey: .quit)
            try container.encode(appWide.desktop, forKey: .desktop)
            try container.encode(appWide.space, forKey: .space)
            try container.encode(appWide.mode, forKey: .mode)
            try container.encode(appWide.tiling, forKey: .tiling)
            try container.encode(appWide.vision, forKey: .kiwivision)
            try container.encode(appWide.hyper, forKey: .hyper)
            try container.encode(appWide.kiwihub, forKey: .kiwihub)
            try container.encode(appWide.modifier, forKey: .modifier)
        }
        try container.encodeIfPresent(look, forKey: .look)
        try container.encodeIfPresent(
            shortcutOffer,
            forKey: .shortcutOffer
        )
    }
}
