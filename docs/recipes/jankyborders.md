---
title: JankyBorders Integration
description: Layout-aware window border colors based on the
  active layout mode.
---

# JankyBorders

[JankyBorders](https://github.com/FelixKratz/JankyBorders)
(macOS window borders via [`borders`](https://github.com/FelixKratz/borders))
works standalone out of the box — it follows macOS focus
automatically.

For layout-aware border colors, subscribe to the `layout_change`
event and pass the mode name to `borders`:

```lua
KiwiDesk.on("layout_change", function(space_id, mode)
    local colors = {
        bsp       = "0xFFBD93F9",  -- purple
        stack     = "0xFF50FA7B",  -- green
        scrolling = "0xFF8BE9FD",  -- cyan
        monocle   = "0xFFFF79C6",  -- pink
        grid      = "0xFFFFB86C",  -- orange
        floating  = "0x00000000",  -- transparent
    }
    local c = colors[mode] or "0xFFFFFFFF"
    KiwiDesk.exec("borders active_color=" .. c)
end)
```

Install `borders` via Homebrew:

```sh
brew install felixkratz/formulae/borders
```

Color format is `0xAARRGGBB` (alpha + RGB). The example colors
are from [Dracula](https://draculatheme.com/) — adjust to your
theme.
