# Temperz

A small Zig CLI to install dev tools, link or remove dotfiles, and pull repo updates.

## Usage

Build and run from the repository root:

```sh
zig build
./zig-out/bin/temperz
```

### Portable x86_64 Linux build

To build an executable for x86_64 Linux without requiring the build machine's
CPU features or a particular system libc version:

```sh
zig build -Dtarget=x86_64-linux -Dcpu=baseline
```

The resulting `zig-out/bin/temperz` is statically linked and can be copied to
other x86_64 Linux systems without installing Zig. This avoids distribution-specific
libc dependencies, but still requires a compatible Linux kernel; it does not
guarantee support for every historical Linux version. Plain `zig build` targets
the build machine by default.

Commands used to install dependencies still require their corresponding shell,
package manager, or other tools on the destination system. Pulling updates requires
Git. The `configs/` and `vm/` folders are resolved from the current working directory,
as described below.

## Where to put configs

**Temperz looks for `configs/` and optional `vm/` in your current working directory, not beside
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
├── vm/                    # Optional, used only by VM menu actions
│   ├── home/              # VM files and directories to link into ~/
│   │   └── .bashrc        # Example: becomes ~/.bashrc
│   ├── configs/           # VM files and directories to link into ~/.config/
│   │   └── i3/            # Example: becomes ~/.config/i3
│   └── install.config     # Optional VM dependency-install commands, same format
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

`vm/home/` and `vm/configs/` are independently optional. Put `i3/` directly in
`vm/configs/`, not inside a `.config/` wrapper: each entry gets its own symlink,
so an existing `~/.config/` directory is preserved. Existing destination entries
such as `~/.config/i3` are still skipped, not overwritten or merged.

If upgrading from the earlier VM layout, move home entries from `configs/vm/`
to `vm/home/`, and entries inside its `.config/` directory to `vm/configs/`.
Move `configs/install-vm.config` to `vm/install.config`. The old paths are no
longer scanned.

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
  symlink targets untouched. Real directories are removed recursively, including
  their contents. Missing paths are skipped. Matching files and directories are
  deleted even when they are not symlinks, so use with care.
- **Setup VM:** Install one or all configs from `vm/home/` into `~/` and from
  `vm/configs/` into `~/.config/`, using the same preview and confirmation as normal installs.
  `~/.config/` must already exist. These configs
  have `for_vm = true` and are excluded from normal installs. Removal lists both
  normal and VM configs. Existing destination paths are skipped, not replaced.
- **Preview and confirm:** Both config actions show a read-only dry run before
  changing anything, whether selecting one item or all items. Installation previews
  links and skips existing paths; removal previews deletions and explicitly warns
  when a directory and all its contents will be deleted recursively. Press Enter
  to proceed, or type anything and press Enter to cancel. End-of-input also cancels.
  If nothing would change, no confirmation is requested. The preview reflects the
  filesystem at that moment; execution still uses the normal install/remove behavior.
- **Install dependencies:** Run one or all commands from `configs/install.config`
  with interactive prompts. Use one trusted shell command per line; blank lines
  are ignored, and batch installation stops at the first failure.
- **Install VM deps:** Run one or all commands from `vm/install.config`,
  using the same format and execution behavior as regular dependencies. Missing
  or empty files show an empty command list. VM and regular commands stay separate.
- **Pull updates:** Run `git pull` in the current repository.
- **Terminal menu:** Select numbered actions and press Enter. Empty input exits
  the main menu or processes all items in a config/dependency submenu. Select
   `0` in the install, VM setup, remove, or dependency submenu to go back to the main menu
  without making changes.

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
  [5]  Setup VM              Link your VM dotfiles
  [6]  Install VM deps       Set up your VM tools
  [7]  Exit

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
