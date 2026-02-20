#!/usr/bin/env bash

# dirdiff.sh — Compare two directory trees and generate unified diffs
#
# Recursively walks DIR1 and DIR2, producing a .diff file for every file that
# exists in both trees but differs in content.  Files present in only one side
# are listed in a separate report (_only_in_one_side.txt).
#
# Filtering options allow targeting specific extensions (--include-ext,
# --exclude-ext) or individual filenames such as Makefile (--include-name,
# --exclude-name).

set -euo pipefail

# Help.
usage() {
    cat <<EOF
Usage:
  $0 [options] DIR1 DIR2 OUTDIR

Options:
  --include-ext ext1,ext2,...       Target extensions (dot optional)
  --exclude-ext ext1,ext2,...       Extensions to exclude (dot optional)
  --include-name name1,name2,...    Explicit filenames without extension (e.g., Makefile,Dockerfile)
  --exclude-name name1,name2,...    Explicit filenames to exclude
EOF
    exit 1
}

# Initialize.
INCLUDE_EXTS=()
EXCLUDE_EXTS=()
INCLUDE_NAMES=()
EXCLUDE_NAMES=()

# Parse command-line options.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --include-ext)
            IFS=',' read -r -a INCLUDE_EXTS <<< "$2"
            shift 2
            ;;
        --exclude-ext)
            IFS=',' read -r -a EXCLUDE_EXTS <<< "$2"
            shift 2
            ;;
        --include-name)
            IFS=',' read -r -a INCLUDE_NAMES <<< "$2"
            shift 2
            ;;
        --exclude-name)
            IFS=',' read -r -a EXCLUDE_NAMES <<< "$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        --*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Validate arguments.
[[ $# -eq 3 ]] || usage
DIR1="$(cd "$1" && pwd)"
DIR2="$(cd "$2" && pwd)"
OUT="$(mkdir -p "$3" && cd "$3" && pwd)"

# Normalize extensions (executed once at startup).
normalize_ext() {
    local ext="$1"
    # Remove a leading dot if present.
    ext="${ext#.}"
    # Convert the extention to lowercase.
    echo "${ext,,}"
}

NORM_INCLUDE_EXTS=()
for e in "${INCLUDE_EXTS[@]+"${INCLUDE_EXTS[@]}"}"; do
    NORM_INCLUDE_EXTS+=("$(normalize_ext "$e")")
done

NORM_EXCLUDE_EXTS=()
for e in "${EXCLUDE_EXTS[@]+"${EXCLUDE_EXTS[@]}"}"; do
    NORM_EXCLUDE_EXTS+=("$(normalize_ext "$e")")
done

# Filename filter function.
# Return 0 if the file should be included; otherwise return 1.
match_file() {
    local file="$1"
    # e.g. ./src/main.c -> main.c
    local basename="${file##*/}"

    # Check --exclude-name (highest priority).
    local n
    for n in "${EXCLUDE_NAMES[@]+"${EXCLUDE_NAMES[@]}"}"; do
        [[ "$basename" == "$n" ]] && return 1
    done

    # If matched by --include-name, accept immediately (bypass extension filters).
    for n in "${INCLUDE_NAMES[@]+"${INCLUDE_NAMES[@]}"}"; do
        [[ "$basename" == "$n" ]] && return 0
    done

    # Extract extension (empty if none).
    local ext="${basename##*.}"
    [[ "$basename" == "$ext" ]] && ext=""
    ext="${ext#.}"
    ext="${ext,,}"

    # Check include-ext if specified.
    if [[ ${#NORM_INCLUDE_EXTS[@]} -gt 0 ]]; then
        [[ -z "$ext" ]] && return 1
        local ok=false
        local e
        for e in "${NORM_INCLUDE_EXTS[@]}"; do
            [[ "$ext" == "$e" ]] && ok=true && break
        done
        $ok || return 1
    fi

    # Check exclude-ext.
    local e
    for e in "${NORM_EXCLUDE_EXTS[@]+"${NORM_EXCLUDE_EXTS[@]}"}"; do
        [[ "$ext" == "$e" ]] && return 1
    done

    return 0
}

# Collect target files (sorted, NUL-delimited).
collect_files() {
    local dir="$1"
    (cd "$dir" && find . -type f -print0 | sort -z)
}

# Detect files that exist only in one directory.
only_in_dir1=()
only_in_dir2=()

while IFS= read -r -d '' file; do
    # Add file to only_in_dir1, if it does not exist in DIR2.
    match_file "$file" || continue
    if [[ ! -f "$DIR2/$file" ]]; then
        only_in_dir1+=("$file")
    fi
done < <(collect_files "$DIR1")

while IFS= read -r -d '' file; do
    # Add file to only_in_dir1, if it does not exist in DIR1.
    match_file "$file" || continue
    if [[ ! -f "$DIR1/$file" ]]; then
        only_in_dir2+=("$file")
    fi
done < <(collect_files "$DIR2")

# Report files that exist onyly on one side.
if [[ ${#only_in_dir1[@]} -gt 0 || ${#only_in_dir2[@]} -gt 0 ]]; then
    report="$OUT/_only_in_one_side.txt"
    {
        # Files that exist only in DIR1.
        if [[ ${#only_in_dir1[@]} -gt 0 ]]; then
            echo "=== Only in DIR1 ($DIR1) ==="
            printf '  %s\n' "${only_in_dir1[@]}"
            echo
        fi

        # Files that exist only in DIR2.
        if [[ ${#only_in_dir2[@]} -gt 0 ]]; then
            echo "=== Only in DIR2 ($DIR2) ==="
            printf '  %s\n' "${only_in_dir2[@]}"
            echo
        fi
    } | tee "$report"
    echo "(Saved to $report)"
    echo
fi

# Generate unified diffs for files present in both directories.
diff_count=0

while IFS= read -r -d '' file; do
    match_file "$file" || continue
    if [[ -f "$DIR2/$file" ]]; then
        tmpdiff="$(mktemp)"
        if ! diff -u "$DIR1/$file" "$DIR2/$file" > "$tmpdiff"; then
            out="$OUT/$file.diff"
            mkdir -p "$(dirname "$out")"
            mv "$tmpdiff" "$out"
            diff_count=$((diff_count + 1))
        else
            rm -f "$tmpdiff"
        fi
    fi
done < <(collect_files "$DIR1")

# Summary.
echo "Done: $diff_count diff file(s) written to $OUT"
