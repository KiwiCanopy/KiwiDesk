import Foundation

/// One pickable glyph: an SF Symbol name or an emoji, with
/// keyword tags so search matches meaning, not just the
/// symbol's literal name (#68 §6.4).
struct IconChoice: Identifiable, Hashable {
    let glyph: String
    /// Space-separated search tags.
    let tags: String
    var id: String { glyph }

    init(_ glyph: String, _ tags: String) {
        self.glyph = glyph
        self.tags = tags
    }

    func matches(_ query: String) -> Bool {
        glyph.localizedCaseInsensitiveContains(query)
            || tags.localizedCaseInsensitiveContains(query)
    }
}

/// The curated icon catalog shared by mode icons and space
/// icons — one vocabulary, one component (§6.4/§6.5). SF
/// Symbols render from macOS itself (nothing is bundled); the
/// system catalog isn't enumerable at runtime, but any valid
/// symbol name typed into the search appears as a result (the
/// exact-name escape hatch).
enum IconCatalog {
    static let symbols: [IconChoice] = [
        // Web / communication
        .init("globe", "web browser internet safari network"),
        .init("envelope", "mail email message inbox"),
        .init("paperplane", "send message telegram mail"),
        .init(
            "bubble.left.and.bubble.right",
            "chat message talk slack discord"
        ),
        .init("phone", "call telephone facetime"),
        .init("video", "video call meeting zoom camera"),
        .init(
            "antenna.radiowaves.left.and.right",
            "radio signal broadcast stream"
        ),
        .init("wifi", "network wireless internet"),
        // Work / code
        .init("terminal", "shell console code command cli"),
        .init("curlybraces", "code programming develop lua"),
        .init(
            "chevron.left.forwardslash.chevron.right",
            "code html develop web"
        ),
        .init("hammer", "build tools develop xcode"),
        .init("wrench.adjustable", "tools fix settings utility"),
        .init("cpu", "processor chip system hardware"),
        .init("externaldrive", "disk drive storage server"),
        .init("server.rack", "server backend infra host"),
        .init("keyboard", "typing keys input shortcuts"),
        .init("desktopcomputer", "mac desktop computer imac"),
        .init("laptopcomputer", "macbook laptop computer"),
        .init("display", "monitor screen display"),
        // Writing / documents
        .init("doc.text", "document file text page"),
        .init("doc.richtext", "document article richtext"),
        .init("note.text", "notes memo write"),
        .init("pencil", "write edit draft"),
        .init("pencil.and.outline", "draw sketch annotate"),
        .init("book", "read book docs manual"),
        .init("books.vertical", "library books research read"),
        .init("newspaper", "news feed articles rss"),
        .init("text.justify", "text writing editor"),
        .init("folder", "files folder finder documents"),
        .init("archivebox", "archive storage box backup"),
        .init("tray.full", "inbox tray tasks queue"),
        // Design / media
        .init("paintbrush", "design paint art color"),
        .init("paintpalette", "design palette color art"),
        .init("photo", "image picture photo gallery"),
        .init("camera", "photo camera capture"),
        .init("film", "video movie film editing"),
        .init("music.note", "music audio song spotify"),
        .init("headphones", "music audio listen podcast"),
        .init("mic", "microphone record audio podcast"),
        .init("waveform", "audio sound wave edit"),
        .init("scissors", "cut edit crop"),
        .init("wand.and.stars", "magic effects edit ai"),
        // Productivity / planning
        .init("calendar", "calendar schedule dates plan"),
        .init("checklist", "todo tasks checklist plan"),
        .init("checkmark.circle", "done task check complete"),
        .init("list.bullet", "list items overview"),
        .init("chart.bar", "chart statistics analytics data"),
        .init("chart.line.uptrend.xyaxis", "chart graph finance stocks trend"),
        .init("chart.pie", "chart statistics share data"),
        .init("dollarsign.circle", "money finance banking budget"),
        .init("creditcard", "payment banking money card"),
        .init("briefcase", "work business office job"),
        .init("clock", "time clock schedule timer"),
        .init("timer", "timer pomodoro countdown focus"),
        .init("alarm", "alarm wake reminder"),
        .init("hourglass", "waiting time pending"),
        // Places / life
        .init("house", "home main personal house"),
        .init("building.2", "office work company building"),
        .init("cart", "shopping store buy cart"),
        .init("bag", "shopping bag store purchase"),
        .init("gift", "present gift birthday"),
        .init("fork.knife", "food eat restaurant cooking"),
        .init("cup.and.saucer", "coffee tea break cafe"),
        .init("car", "car drive travel commute"),
        .init("airplane", "travel flight trip vacation"),
        .init("map", "map navigation location travel"),
        .init("mappin.and.ellipse", "location place pin map"),
        .init("figure.walk", "walk fitness health steps"),
        .init("figure.run", "run fitness sport exercise"),
        .init("dumbbell", "gym fitness weights sport"),
        .init("heart", "health love favorite like"),
        .init("cross.case", "health medical doctor"),
        .init("pills", "medicine health pharmacy"),
        .init("bed.double", "sleep rest bedroom"),
        .init("pawprint", "pet dog cat animal"),
        .init("leaf", "nature plant green eco"),
        .init("tree", "nature forest outdoors"),
        .init("mountain.2", "outdoors hiking mountains"),
        .init("beach.umbrella", "vacation beach holiday"),
        // Games / fun
        .init("gamecontroller", "games gaming play controller"),
        .init("dice", "games random dice board"),
        .init("puzzlepiece", "puzzle games plugin extension"),
        .init("tv", "tv streaming watch netflix"),
        .init("play.rectangle", "video youtube watch play"),
        .init("sportscourt", "sports court game"),
        // Abstract / markers
        .init("star", "favorite star important bookmark"),
        .init("star.fill", "favorite star important marked"),
        .init("flag", "flag marker milestone priority"),
        .init("tag", "tag label category"),
        .init("bookmark", "bookmark save read later"),
        .init("pin", "pin fixed important"),
        .init("bell", "notification alert reminder"),
        .init("bolt", "fast energy power quick"),
        .init("flame", "hot fire trending urgent"),
        .init("sparkles", "new shiny magic ai special"),
        .init("moon", "night dark sleep focus"),
        .init("sun.max", "day light bright morning"),
        .init("cloud", "cloud sync weather storage"),
        .init("drop", "water drop liquid"),
        .init("snowflake", "cold winter freeze"),
        .init("wind", "air wind weather"),
        .init("target", "goal target aim focus"),
        .init("scope", "aim precision focus target"),
        .init("lightbulb", "idea inspiration tip"),
        .init("brain", "think mind learn study ai"),
        .init("graduationcap", "study school university learn"),
        .init("atom", "science physics research"),
        .init("flask", "science chemistry experiment lab"),
        .init("lock", "secure private lock password"),
        .init("lock.open", "unlocked open access"),
        .init("key", "key password access login"),
        .init("shield", "security protection privacy vpn"),
        .init("eye", "watch view monitor observe"),
        .init("magnifyingglass", "search find lookup"),
        .init("gearshape", "settings configure system"),
        .init("slider.horizontal.3", "settings tune adjust controls"),
        .init("command", "command key mac shortcut"),
        .init("option", "option key mac alt"),
        .init("square.grid.2x2", "grid apps layout tiles"),
        .init("square.grid.3x3", "grid layout tiles many"),
        .init("rectangle.3.group", "layout windows tiling kiwidesk"),
        .init("rectangle.split.3x1", "layout columns split spaces"),
        .init("square.stack.3d.up", "stack layers profiles"),
        .init("macwindow", "window app screen"),
        .init("circle.grid.3x3", "dots grid layout"),
        .init("infinity", "infinite loop forever"),
        .init("number", "number hash count"),
    ]

    static let emoji: [IconChoice] = [
        .init("🥝", "kiwi kiwidesk fruit green brand"),
        .init("🌐", "web internet globe browser"),
        .init("📧", "mail email message"),
        .init("💬", "chat message talk"),
        .init("💻", "laptop code computer work"),
        .init("🖥️", "desktop computer monitor"),
        .init("⌨️", "keyboard typing keys"),
        .init("🧑\u{200D}💻", "code developer programmer"),
        .init("📝", "notes write memo"),
        .init("📚", "books read study library"),
        .init("📰", "news articles feed"),
        .init("📁", "folder files documents"),
        .init("🎨", "design art paint color"),
        .init("📷", "photo camera picture"),
        .init("🎬", "video film movie editing"),
        .init("🎵", "music song audio"),
        .init("🎧", "headphones music podcast"),
        .init("🎤", "microphone record sing"),
        .init("📅", "calendar schedule plan"),
        .init("✅", "done task check todo"),
        .init("📊", "chart statistics data"),
        .init("📈", "chart trend stocks finance"),
        .init("💰", "money finance budget"),
        .init("💼", "work business office"),
        .init("⏰", "alarm clock time"),
        .init("🏠", "home house personal"),
        .init("🏢", "office building company work"),
        .init("🛒", "shopping cart store"),
        .init("🍽️", "food eat restaurant"),
        .init("☕", "coffee tea break cafe"),
        .init("✈️", "travel flight vacation"),
        .init("🗺️", "map travel navigation"),
        .init("🏃", "run fitness sport"),
        .init("💪", "gym fitness strength"),
        .init("❤️", "heart love health favorite"),
        .init("🐾", "pet animal dog cat"),
        .init("🌿", "nature plant green"),
        .init("🎮", "games gaming controller"),
        .init("🧩", "puzzle plugin extension"),
        .init("📺", "tv streaming watch"),
        .init("⭐", "star favorite important"),
        .init("🚩", "flag marker milestone"),
        .init("🔖", "bookmark tag save"),
        .init("🔔", "bell notification alert"),
        .init("⚡", "bolt fast energy quick"),
        .init("🔥", "fire hot trending"),
        .init("✨", "sparkles new magic"),
        .init("🌙", "moon night dark"),
        .init("☀️", "sun day light"),
        .init("🎯", "target goal focus"),
        .init("💡", "idea lightbulb tip"),
        .init("🧠", "brain think learn ai"),
        .init("🎓", "study school graduate"),
        .init("🔬", "science research lab"),
        .init("🔒", "lock secure private"),
        .init("🔑", "key password access"),
        .init("🛡️", "shield security privacy"),
        .init("🔍", "search find lookup"),
        .init("⚙️", "settings gear configure"),
        .init("📌", "pin fixed important"),
        .init("🚀", "rocket launch fast startup"),
    ]

    // MARK: - Recents (app-wide, shared by both uses)

    private static let recentsKey = "IconPicker.recents"
    private static let recentsLimit = 8

    static func recents() -> [String] {
        UserDefaults.standard.stringArray(
            forKey: recentsKey
        ) ?? []
    }

    static func noteRecent(_ glyph: String) {
        guard !glyph.isEmpty else { return }
        var list = recents().filter { $0 != glyph }
        list.insert(glyph, at: 0)
        UserDefaults.standard.set(
            Array(list.prefix(recentsLimit)),
            forKey: recentsKey
        )
    }
}
