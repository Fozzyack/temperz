# Temperz

A small Zig CLI to install dev tools, link or remove dotfiles, and pull repo updates.

## Usage

Build and run from the repository root:

```sh
zig build
./zig-out/bin/temperz
```

## Features

- **Install configs:** Symlink files and directories from `configs/home/` into
  `~/`, and from `configs/configs/` into `~/.config/`. Existing paths are skipped;
  `~/.config/` must already exist.
- **Remove configs:** Remove matching paths from `~/` and `~/.config/`, leaving
  repository sources untouched. Missing paths are skipped. This does not check
  whether a matching file is a symlink, so use with care.
- **Install dependencies:** Run one or all commands from `configs/install.config`
  with interactive prompts. Use one trusted shell command per line; blank lines
  are ignored, and batch installation stops at the first failure.
- **Pull updates:** Run `git pull` in the current repository.
- **Terminal menu:** Select numbered actions and press Enter. Empty input exits
  the main menu or processes all items in a config/dependency submenu.

## Terminal appearance

```text
  temperz  /  dev environment
  Your tools. Your dotfiles. One place.

  ----------------------------------------------------

  What would you like to do?
  Choose an action to get started.

  [1]  Install configs       Link your dotfiles
  [2]  Remove configs        Unlink your dotfiles
  [3]  Install dependencies  Set up your dev tools
  [4]  Pull updates          Sync this repository
  [5]  Exit

  ----------------------------------------------------
  Type a number + Enter  /  Enter to exit

  >
```

A compact layout with a cyan title, numbered actions, bold headings, and muted
descriptions. Dividers separate the menu from its keyboard hints, with a simple
`>` prompt below. Interactive terminals clear the screen between menus.

Set `NO_COLOR=1` to disable colors; redirected output and `TERM=dumb` use plain
text without screen-clearing escapes.
