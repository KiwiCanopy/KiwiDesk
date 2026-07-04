import Foundation

/// Curated icon choices for the mode picker. SF Symbols render
/// from macOS itself (nothing is bundled); this is just a list
/// of names, since the system catalog isn't enumerable at
/// runtime. Emoji are a convenience grid — any single character
/// also works via the Text option.
enum ModeIcons {
    static let symbols: [String] = [
        "arrow.left.and.right", "arrow.up.and.down",
        "arrow.up.left.and.arrow.down.right",
        "arrow.triangle.2.circlepath", "gearshape",
        "gearshape.fill", "slider.horizontal.3", "hammer",
        "wrench.adjustable", "wand.and.stars", "paintbrush",
        "square.grid.2x2", "square.grid.3x3",
        "rectangle.3.group", "rectangle.split.3x1",
        "rectangle.split.2x2", "square.stack.3d.up",
        "macwindow", "sidebar.left", "sidebar.right",
        "command", "option", "keyboard", "cursorarrow",
        "cursorarrow.rays", "scope", "target", "flag",
        "bolt", "bolt.fill", "star", "star.fill", "moon",
        "sun.max", "lightbulb", "magnifyingglass", "lock",
        "lock.open", "eye", "bell", "tag", "bookmark", "pin",
        "map", "globe", "terminal", "cpu", "display",
        "circle.grid.3x3", "play", "pause", "record.circle",
        "flame", "leaf", "drop", "wind", "sparkles",
    ]

    static let emoji: [String] = [
        "📐", "⚙️", "🔧", "🔨", "🎯",
        "✨", "🚀", "🖥️", "⌨️", "🎨",
        "🔍", "🔒", "👁️", "🔔", "🏷️",
        "📌", "🗺️", "🌐", "💻", "▶️",
        "⏸️", "⏺️", "🎮", "🧩", "📊",
        "📈", "🖼️", "🔴", "🟢", "🟡",
        "🔵", "⭐", "🌙", "☀️", "💡",
        "🧭", "🔥", "🍃", "💧", "🌪️",
    ]
}
