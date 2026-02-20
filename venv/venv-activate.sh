#!/usr/bin/env bash

# ------------------------------------------------------------
# venv-activate
#
# Activate a Python virtual environment located at:
#   ~/python-venv/<venv-name>
#
# Features:
#   - Tab completion for venv names
#   - Automatic deactivation of an already active venv
#   - Explicit deactivate command (venv-deactivate)
# ------------------------------------------------------------

# Activate a virtual environment
venv-activate () {
    local venv_name="$1"
    local venv_dir

    # No argument given
    if [[ -z "$venv_name" ]]; then
        echo "usage: venv-activate <venv-name>"
        return 1
    fi

    venv_dir="$HOME/python-venv/$venv_name"

    # Check that the directory exists
    if [[ ! -d "$venv_dir" ]]; then
        echo "venv not found: $venv_dir"
        return 1
    fi

    # Check that this looks like a valid venv
    if [[ ! -f "$venv_dir/bin/activate" ]]; then
        echo "invalid venv: $venv_dir/bin/activate not found"
        return 1
    fi

    # If another virtual environment is already active, deactivate it first
    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate
    fi

    # Activate the requested virtual environment
    # shellcheck disable=SC1090
    source "$venv_dir/bin/activate"
}

# Explicitly deactivate the current virtual environment
venv-deactivate () {
    if [[ -z "$VIRTUAL_ENV" ]]; then
        echo "no virtual environment is currently active"
        return 1
    fi

    deactivate
}

# ------------------------------------------------------------
# Bash completion for venv-activate
# ------------------------------------------------------------
_venv_activate_complete () {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"

    # Complete directory names under ~/python-venv
    COMPREPLY=(
        $(compgen -W "$(ls -1 "$HOME/python-venv" 2>/dev/null)" -- "$cur")
    )
}

complete -F _venv_activate_complete venv-activate
