import Foundation

extension Profile {
    /// Format version of the profile schema (#902); 0 =
    /// unversioned legacy. 2 since the scroll-duration rename
    /// (#1020), 3 since the retired `resize.feedback` drop
    /// (#1255), 4 since the absent Liquid Glass leaves' fill
    /// (#1369), 5 since the track limit counts the overflow
    /// track (#1354), 6 since a dormant profile holds no set
    /// beside its `monitor_count` (#1530), 7 since a shortcut
    /// override may leave a shared combo out (#1393) — no step
    /// for either: an older reader refuses the shape, and the
    /// stamp says why — 8 since the bars' shared fields moved to
    /// `kiwishelf` (#1517), 9 since the drag markers' and sticky
    /// mark's Liquid Glass leaves are filled (#1620/#1621), 10
    /// since `float_nudge` retired for `float_placement` (#1674),
    /// 11 since each bar took its edge back from `kiwishelf`
    /// (#1731), 12 since `space_bar.glyph_cap` became
    /// `glyph_span` (#1528), 13 since a profile states which look
    /// it wears and one from before is stamped `own` (#1752), 14
    /// since `app_bar.content` retired (#1528), 15 since a layer
    /// override holds one chord per navigation action (#1797), 16
    /// since the Space switch plates' Liquid Glass leaf was filled
    /// (#1956; the step retired with the slide, #2228), 17 since a
    /// stored app shortcut calls `focus_or_spawn` (#1511), 18 since
    /// a layer override may leave a shared layer out whole (#2022)
    /// — no step, as for 7 — 19 since a stored
    /// `on_space_change: false` was turned on once (#1931; retired
    /// with the slide, #2228), 20 for #2143's step withdrawn by
    /// #2228 (kept so a development build's file loads), 21 since
    /// a stored `show_*` call opens `kiwihub.show` (#2265), 22 since
    /// the layouts side became View (#2309), 23 since a profile
    /// carries a stable `id` (#2324), 24 since a bar's on/off
    /// switch became `visibility: hidden` (#761).
    /// 25 since the minimum window
    /// size is one width × height per layout (#2237; 24 is #761's,
    /// a parallel branch, so a file either stamped crosses here),
    /// 26 so a file a build without #761 stamped 25 crosses #761's
    /// step too, which reads content and so runs twice harmlessly,
    /// 27 since a Go to Desktop row on `✦` + digit takes `✦⌥` +
    /// digit (#2460), 28 since the shelf glide is its expand
    /// (`animations.*_expand*`, owner ruling 2026-10-21), 29 since
    /// `overflow_style` retired (#2235), 30 since the per-layout
    /// `wrap_focus` switches retired for `focus_wrap` (#2493), 31
    /// since the seeded pin row on ⌃⌥P runs Pocket (#2446), 32 the
    /// pocket's place is KiwiShelf's (#2678), 33 the drag markers'
    /// look retired (#2797), 34 its Show is the profile's (#2978),
    /// 35 a binding may be a key sequence, with no step (#1871),
    /// 36 the gestures are one `gesture` map (#3199), 37 a 0
    /// reveal or expand duration is its toggle off (#3236), 38 its
    /// own look carries no animation length (#3237), 39 the
    /// `gesture` map may hold the four-finger pinch and spread
    /// slots, with no step (#1873).
    /// The bump is what RUNS a step: `needsMigration`
    /// short-circuits on it, so a step reaching this shape owes one
    /// whatever it rewrites — a retired key decodes to the default
    /// and an absent leaf to the NEW default, silently, without it.
    public static let currentFormat = 39
}
