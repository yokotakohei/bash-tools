# bash-tools

A small collection of Bash utilities for interactive shell usage on Linux
(mainly Ubuntu).

This repository contains **Bash functions and helper scripts intended to be _sourced_ from `.bashrc`**, not executed as standalone commands.

---

## Overview

- No external dependencies
- Designed for interactive shells
- Modular and maintainable layout
- Safe integration via `~/.bashrc.d`

This repository is primarily maintained for personal use.

---

## Requirements

- Bash 4.x or later
- Linux (tested on Ubuntu)

## Tested environment

- Ubuntu 24.04 LTS
- Bash 5.2.21

---

## Repository structure

```
bash-tools/
├── README.md
├── LICENSE
├── install.sh
└── venv/
  └── venv-activate.sh
```

- Scripts are grouped by functionality inside the repository
- Only selected `.sh` files are installed into `~/.bashrc.d`

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/yokotakohei/bash-tools.git
```

### 2. Ensure `~/.bashrc.d` is sourced from `.bashrc`

Add the following to your `~/.bashrc` if it is not already present:

```bash
if [ -d "$HOME/.bashrc.d" ]; then
    for f in "$HOME/.bashrc.d"/*.sh; do
        [ -r "$f" ] && source "$f"
    done
fi
```

### 3. Run the installer

```bash
cd bash-tools
chmod +x install.sh
./install.sh
```

The installer creates symbolic links from selected scripts in this repository
to `~/.bashrc.d`.

This script is safe to re-run (idempotent).

### 4. Reload your shell

```bash
source ~/.bashrc
```

---

## Included tools

### venv-activate

Activate Python virtual environments stored under:

```bash
~/python-venv/<venv-name>
```

#### Features

- Bash tab completion for venv names

- Automatic deactivation of an already active venv

- Explicit venv-deactivate command

#### Usage

```bash
venv-activate myenv
venv-deactivate
```

---

## Design principles

### Functions over executables

Scripts are meant to modify shell state and therefore must be sourced.

### Minimal side effects

Every script should be safe to source on shell startup.

### Explicit installation

Only explicitly listed scripts are installed via `install.sh`.

---

## Notes on .bashrc.d

`~/.bashrc.d` is treated as a runtime directory

It should contain only `.sh` files

Files are sourced automatically at shell startup

This repository itself is not meant to be placed directly inside `.bashrc.d`

---

## License

MIT License
