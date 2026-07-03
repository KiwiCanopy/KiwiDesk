# Integrations

Ready-to-copy recipes for common companions. All of them use
either the Lua event callbacks in `init.lua` or the CLI event
stream — no plugins required.

## SketchyBar

Space indicator + layout mode display. In `init.lua`:

```lua
KiwiDesk.on("space_change", function(space_id, mode)
    os.execute(
        "sketchybar --trigger kiwi_space_change "
        .. "SPACE=" .. space_id .. " MODE=" .. mode)
end)

KiwiDesk.on("focus_change", function(window_id, app)
    os.execute(
        "sketchybar --trigger kiwi_focus APP='"
        .. app .. "'")
end)
```

In your `sketchybarrc`:

```sh
sketchybar --add event kiwi_space_change
sketchybar --add item kiwi_space left
sketchybar --set kiwi_space \
    script="sketchybar --set kiwi_space label=\"$SPACE ($MODE)\"" \
    --subscribe kiwi_space kiwi_space_change
```

## JankyBorders

JankyBorders works standalone out of the box (it follows macOS
focus). For **layout-aware border colors**, use the layout
change event:

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
    os.execute("borders active_color=" .. c)
end)
```

## Shell Scripts & Everything Else

Any process can stream events as newline-delimited JSON:

```sh
KiwiDesk subscribe space_change | while read -r line; do
    space=$(echo "$line" | jq -r '.data.space_id')
    echo "now on space $space"
done
```

Or query state on demand:

```sh
KiwiDesk get_state | jq '.spaces[] | {id, mode}'
KiwiDesk list_monitors | jq
```

## Hammerspoon

Drive KiwiDesk from Hammerspoon (or vice versa) through the
CLI:

```lua
hs.hotkey.bind({"cmd", "alt"}, "m", function()
    hs.execute("/opt/homebrew/bin/KiwiDesk set_mode monocle",
        true)
end)
```

Tip: KiwiDesk's own modal keybindings (see
[configuration](configuration.md)) cover most Hammerspoon
window-management use cases natively.
