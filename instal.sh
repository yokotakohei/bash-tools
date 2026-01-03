#!/usr/bin/env bash
#
# install.sh
#
# Install bash-tools scripts into ~/.bashrc.d by creating symlinks.
# This script is intentionally minimal and safe to re-run.


set -euo pipefail

# Destination directory sourced by ~/.bashrc
BASHRC_D="$HOME/.bashrc.d"

# Repository root (directory where this script is located)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# List of scripts to install (relative to repo root)
SCRIPTS=(
    "venv/venv-activate.sh"
)

echo "Installing bash-tools..."
echo "Repository: $REPO_ROOT"
echo "Target:     $BASHRC_D"
echo

# Create ~/.bashrc.d if necessary
mkdir -p "$BASHRC_D"

for script in "${SCRIPTS[@]}"; do
    src="$REPO_ROOT/$script"
    dst="$BASHRC_D/$(basename "$script")"

    if [[ ! -f "$src" ]]; then
        echo "Skipping (not found): $src"
        continue
    fi

    if [[ -L "$dst" || -f "$dst" ]]; then
        echo "Already exists, skipping: $dst"
        continue
    fi

    ln -s "$src" "$dst"
    echo "Linked: $dst -> $src"
done

echo
echo "Done."
echo "Reload your shell or run:"
echo "  source ~/.bashrc"
