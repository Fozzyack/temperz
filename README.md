# Temperz

A small Zig CLI to install dev tools, link or remove dotfiles, and pull repo updates.

```sh
zig build
./zig-out/bin/temperz
```

The terminal menu uses a compact layout with color accents and numbered actions.
Type a number and press Enter to select an action; the footer shows what an empty
selection does on each screen. Set `NO_COLOR=1` to disable colors. Redirected output
and `TERM=dumb` use plain text without screen-clearing escape sequences.
