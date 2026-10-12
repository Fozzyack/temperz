# Temperz

A small Zig CLI to install dev tools, link or remove dotfiles, and pull repo updates.

## Usage

Build and run from the repository root:

```sh
zig build
./zig-out/bin/temperz
```

## Where to put configs

**Temperz looks for `configs/` in your current working directory, not beside
the executable.** With the repository layout, keep configs at the repository
root and run `./zig-out/bin/temperz` from that root:

```text
temperz/                   # Run commands from this directory
├── configs/
│   ├── home/              # Files and directories to link into ~/
│   │   └── .bashrc        # Example: becomes ~/.bashrc
│   ├── configs/           # Files and directories to link into ~/.config/
│   │   └── nvim/          # Example: becomes ~/.config/nvim
│   └── install.config     # One dependency-install shell command per line
└── zig-out/
    └── bin/
        └── temperz        # Built executable
```

Names are preserved exactly, including leading dots. Create both `configs/home/`
and `configs/configs/`, even if one is empty. Before installing configs, ensure
the destination directory exists:

```sh
mkdir -p ~/.config
```

The executable can live elsewhere, including on your `PATH`. First change into
the directory containing your `configs/` folder, then launch it:

```sh
cd /path/to/your/dotfiles
/path/to/temperz
```

If you place `temperz` and `configs/` side by side, run `./temperz` from that
directory. For the repository build above, running `cd zig-out/bin && ./temperz`
would instead look for `zig-out/bin/configs/`.

Installed configs are symlinks to the source files, so keep the source directory
in place after installation.

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
  [ temperz ]  DEV ENVIRONMENT / CONTROL PANEL
  Your tools. Your dotfiles. One place.

  +--------------------------------------------------+

  What would you like to do?
  Choose an action to get started.

  [1]  Install configs       Link your dotfiles
  [2]  Remove configs        Unlink your dotfiles
  [3]  Install dependencies  Set up your dev tools
  [4]  Pull updates          Sync this repository
  [5]  Exit

  +--------------------------------------------------+
  Type a number + Enter  /  Enter to exit

  READY >
```

A retro text control panel styled for the WezTerm and Ghostty configs in
`configs/`: burnt-orange controls, teal dividers, warm-cream headings, and muted
descriptions. Colors use the configs' shared ANSI palette, so the terminal keeps
its own charcoal background, transparency, and Terminess font. Status messages
use ASCII indicators (`[OK]`, `[..]`, `[--]`, `[!!]`) with green successes and red
errors. Interactive terminals clear the screen between menus.

Set `NO_COLOR=1` to disable colors; redirected output and `TERM=dumb` use plain
text without screen-clearing escapes.
