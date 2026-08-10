import AppKit
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// The #678 16b token table, pinned (implementation-plan.md's
/// sidebar-drop closing step owes it).
///
/// **The literals below are the one copy.** They are not a
/// citation of the design folder — that folder is gitignored and
/// cannot be read by anything that runs here — and production
/// deliberately holds no second copy: `SettingsTheme` builds each
/// token from a pair passed to one constructor, and this suite is
/// what says which pair.
///
/// **It resolves, it does not read.** Each token is a
/// `Color` over `NSColor(name:dynamicProvider:)`, so a stored
/// constant and a working dynamic colour look identical from the
/// outside. Every pin therefore draws the token twice, once under
/// each appearance, and compares the resolved sRGB — a token wired
/// to one branch in both modes reds here, which is the way this
/// goes wrong.
@MainActor
@Suite("Settings theme tokens")
struct SettingsThemeTokenTests {
    private struct Pin {
        let name: String
        let light: UInt32
        let dark: UInt32
        let color: Color
        /// Per-mode alpha, 1 for every plain colour token —
        /// `planeRing` is the construction that varies it.
        let lightAlpha: Double
        let darkAlpha: Double

        init(
            _ name: String,
            _ light: UInt32,
            _ dark: UInt32,
            _ color: Color,
            lightAlpha: Double = 1,
            darkAlpha: Double = 1
        ) {
            self.name = name
            self.light = light
            self.dark = dark
            self.color = color
            self.lightAlpha = lightAlpha
            self.darkAlpha = darkAlpha
        }
    }

    private let pins: [Pin] = [
        Pin("page", 0xFB_FC_FA, 0x17_1C_19, SettingsTheme.page),
        Pin("card", 0xFF_FF_FF, 0x1E_25_21, SettingsTheme.card),
        Pin("panel", 0xF4_F6_F1, 0x1A_20_1C, SettingsTheme.panel),
        Pin(
            "sunken",
            0xF4_F7_F1,
            0x23_2B_26,
            SettingsTheme.sunken
        ),
        // Identical in both modes on purpose (#786): the Home
        // plate is a picture of the user's desktop, and what
        // the picture shows must not change with the window's
        // appearance (4g).
        Pin(
            "previewPlate",
            0x12_25_1A,
            0x12_25_1A,
            SettingsTheme.previewPlate
        ),
        Pin(
            "plateInk",
            0xEA_F3_EE,
            0xEA_F3_EE,
            SettingsTheme.plateInk
        ),
        // The keyboard board's own two tokens (#678 pass 5).
        // Fixed in both modes for `previewPlate`'s reason — the
        // board is a picture of a keyboard on that same dark
        // ground. Bound keys and the conflict ring reuse
        // `accent` and `danger`; only these two are the board's.
        Pin(
            "keyFree",
            0x37_46_3B,
            0x37_46_3B,
            SettingsTheme.keyFree
        ),
        Pin(
            "keyConflict",
            0xB0_3A_2A,
            0xB0_3A_2A,
            SettingsTheme.keyConflict
        ),
        Pin(
            "keyReserved",
            0xE0_A3_4A,
            0xE0_A3_4A,
            SettingsTheme.keyReserved
        ),
        Pin(
            "hairline",
            0xE4_E9_E1,
            0x2C_33_2D,
            SettingsTheme.hairline
        ),
        // The 16b dark construction: transparent in light (the
        // fills separate the planes there), a faint light line
        // in dark. The alpha pair IS the pin — a ring wired to
        // one branch draws a solid white line in light.
        Pin(
            "planeRing",
            0xFF_FF_FF,
            0xFF_FF_FF,
            SettingsTheme.planeRing,
            lightAlpha: 0,
            darkAlpha: 0.14
        ),
        Pin("ink", 0x12_25_1A, 0xE6_EC_E6, SettingsTheme.ink),
        Pin("ink2", 0x55_63_5C, 0xA8_B3_A9, SettingsTheme.ink2),
        Pin("ink3", 0x64_72_6A, 0x98_A2_96, SettingsTheme.ink3),
        Pin(
            "groupHeading",
            0x50_6C_37,
            0x9B_B0_7E,
            SettingsTheme.groupHeading
        ),
        Pin(
            "accent",
            0x8D_B3_54,
            0x8D_B3_54,
            SettingsTheme.accent
        ),
        Pin(
            "accentInk",
            0x12_25_1A,
            0x12_25_1A,
            SettingsTheme.accentInk
        ),
        Pin(
            "onAccentKnob",
            0xFF_FF_FF,
            0x12_25_1A,
            SettingsTheme.onAccentKnob
        ),
        Pin(
            "warningSurface",
            0xFD_F1_DD,
            0x3A_2A_18,
            SettingsTheme.warningSurface
        ),
        Pin(
            "warningInk",
            0x9A_62_00,
            0xE0_A3_4A,
            SettingsTheme.warningInk
        ),
        Pin(
            "danger",
            0xB0_3A_2A,
            0xE0_82_76,
            SettingsTheme.danger
        ),
        Pin(
            "savePill",
            0x12_25_1A,
            0x0C_14_10,
            SettingsTheme.savePill
        ),
        Pin(
            "savePillInk",
            0xEA_F3_EE,
            0xEA_F3_EE,
            SettingsTheme.savePillInk
        ),
    ]

    @Test("every token resolves to its pinned light/dark pair")
    func tokensResolveUnderBothAppearances() throws {
        for pin in pins {
            let light = try resolve(pin.color, dark: false)
            let dark = try resolve(pin.color, dark: true)
            #expect(
                light.rgb == pin.light,
                Comment(rawValue: "\(pin.name) light")
            )
            #expect(
                dark.rgb == pin.dark,
                Comment(rawValue: "\(pin.name) dark")
            )
            #expect(
                abs(light.alpha - pin.lightAlpha) < 0.005,
                Comment(rawValue: "\(pin.name) light alpha")
            )
            #expect(
                abs(dark.alpha - pin.darkAlpha) < 0.005,
                Comment(rawValue: "\(pin.name) dark alpha")
            )
        }
    }

    /// Completeness, derived on both sides: the table's own names
    /// against the tokens `SettingsTheme` actually declares.
    ///
    /// A hand-written "there are 16 tokens" would be a tautology
    /// (`.claude/rules/rule-authoring.md`, "derive the number").
    /// This counts the constructor call sites in the shipped
    /// source instead, so a 17th token added without a row here
    /// reds — which is the failure mode, a token nothing pins.
    @Test("the table covers every shipped token")
    func tableCoversEveryToken() throws {
        let source = SourceScan.stripComments(
            try String(contentsOf: themeFile, encoding: .utf8)
        )
        let constructed = source.occurrences(of: "= token(")
        // A scan that matched nothing would pass having looked at
        // nothing (#635).
        #expect(constructed > 0)
        #expect(constructed == pins.count)
        for pin in pins {
            #expect(
                source.contains(
                    "static let \(pin.name) = token("
                ),
                Comment(rawValue: "no token named \(pin.name)")
            )
        }
    }

    private var themeFile: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsTheme.swift"
            )
    }

    /// The token's sRGB under one appearance, packed `0xRRGGBB`,
    /// plus its alpha — pinned separately so a construction token
    /// (`planeRing`) cannot ship solid in the mode it must be
    /// invisible in.
    ///
    /// `performAsCurrentDrawingAppearance` is what makes the
    /// dynamic provider run — reading the colour outside it
    /// resolves against whatever the test host happens to be set
    /// to, which would make both halves of every pin agree by
    /// accident.
    private func resolve(
        _ color: Color,
        dark: Bool
    ) throws -> (rgb: UInt32, alpha: Double) {
        let appearance = try #require(
            NSAppearance(named: dark ? .darkAqua : .aqua)
        )
        var packed: UInt32 = 0
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(color).usingColorSpace(.sRGB)
        }
        let srgb = try #require(resolved)
        packed |= UInt32((srgb.redComponent * 255).rounded()) << 16
        packed |= UInt32((srgb.greenComponent * 255).rounded()) << 8
        packed |= UInt32((srgb.blueComponent * 255).rounded())
        return (packed, Double(srgb.alphaComponent))
    }
}
