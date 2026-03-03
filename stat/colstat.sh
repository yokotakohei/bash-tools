#!/usr/bin/env bash

#
# colstat.sh - Compute column-wise mean and variance from delimited numeric data.
#
# Usage:
#   colstat.sh [-m | -v | -b] [-d delimiter] [file]
#
# Options:
#   -m  Print mean only
#   -v  Print variance only
#   -b  Print mean and variance (2 columns)
#   -d  Specify input field delimiter (default: whitespace)
#   -h  Show this help message
#
# With no options, prints: column_index, mean, and variance (tab-separated).
# If no file is given, reads from standard input.

set -euo pipefail

# Default output mode (empty string means no mode has been selected yet).
mode=""

# Default delimiter (empty string means awk's default whitespace splitting).
delimiter=""

usage() {
    echo "Usage: $0 [-m | -v | -b] [-d delimiter] [file]"
    echo "  -m : mean only"
    echo "  -v : variance only"
    echo "  -b : mean and variance (2 columns)"
    echo "  -d : field delimiter (default: whitespace)"
    echo "  -h : show this help"
    echo "  (default: column_index, mean, variance)"
}

# set_mode ensures that only one of -m, -v, -b is specified.
set_mode() {
    if [ -n "$mode" ]; then
        echo "Error: options -m, -v, and -b are mutually exclusive" >&2
        usage >&2
        exit 1
    fi
    mode="$1"
}

# Parse options.
while getopts "mvbd:h" opt; do
    case "$opt" in
        # Mean only.
        m) set_mode "mean" ;;
        # Variance only.
        v) set_mode "var" ;;
        # Both mean and variance.
        b) set_mode "both" ;;
        # Custom field delimiter.
        d) delimiter="$OPTARG" ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Fall back to the default full output if no mode was selected.
mode="${mode:-full}"

# Determine input source (file or stdin).
input="${1:--}"

# Validate the file if one was specified.
if [ "$input" != "-" ] && [ ! -f "$input" ]; then
    echo "Error: file not found: $input" >&2
    exit 1
fi

# Build awk options array.
# When a delimiter is specified, pass it via -F; otherwise rely on awk's
# default field splitting (which treats runs of whitespace as a single separator).
awk_opts=()
if [ -n "$delimiter" ]; then
    awk_opts+=(-F "$delimiter")
fi

awk "${awk_opts[@]}" -v mode="$mode" '
# Main block: runs for every input line.
# Validates each field and accumulates sums for mean/variance.
{
    # Record the expected column count from the first line.
    if (NR == 1) {
        cols = NF
    } else if (NF != cols) {
        # Reject ragged input to avoid silently producing wrong results.
        printf "Error: inconsistent column count at line %d (expected %d, got %d)\n", NR, cols, NF > "/dev/stderr"
        err = 1
        exit 1
    }

    for (i = 1; i <= NF; i++) {
        val = $i

        # Detect IEEE 754 special values (NaN, Inf, Infinity) with optional sign.
        # These appear in output from Fortran, C, Python, etc. and would produce
        # meaningless statistics, so we collect every occurrence and report them all.
        if (tolower(val) ~ /^[+-]?(nan|inf(inity)?)$/) {
            nan_inf_count++
            # Record up to a reasonable limit to avoid flooding stderr.
            if (nan_inf_count <= 20) {
                printf "  line %d, column %d: %s\n", NR, i, val > "/dev/stderr"
            }
            has_nan_inf = 1
            continue
        }

        # Accept integers, decimals, signed values, and scientific notation.
        if (val !~ /^[+-]?([0-9]+\.?[0-9]*|[0-9]*\.?[0-9]+)([eE][+-]?[0-9]+)?$/) {
            printf "Error: non-numeric value \"%s\" at line %d, column %d\n", val, NR, i > "/dev/stderr"
            err = 1
            exit 1
        }

        # Accumulate running totals for the one-pass mean/variance formula:
        #   mean     = sum / n
        #   variance = (sum_sq / n) - mean^2
        sum[i]    += val
        sum_sq[i] += val * val
    }

    # Track total number of data rows.
    rows = NR
}

# END block: compute and print statistics for each column.
END {
    # If the main block exited on error, suppress further output.
    if (err) exit 1

    # Report all NaN/Inf occurrences found during the scan.
    if (has_nan_inf) {
        if (nan_inf_count > 20) {
            printf "  ... and %d more\n", nan_inf_count - 20 > "/dev/stderr"
        }
        printf "Error: found %d NaN/Inf value(s); cannot compute meaningful statistics\n", nan_inf_count > "/dev/stderr"
        exit 1
    }

    # Guard against empty input (avoids division by zero).
    if (rows == 0) {
        print "Error: no input data" > "/dev/stderr"
        exit 1
    }

    for (i = 1; i <= cols; i++) {
        # Population mean and variance (not sample variance).
        mean     = sum[i] / rows
        variance = (sum_sq[i] / rows) - (mean * mean)

        # Format output according to the selected mode.
        if (mode == "mean") {
            printf "%.6f\n", mean
        } else if (mode == "var") {
            printf "%.6f\n", variance
        } else if (mode == "both") {
            printf "%.6f\t%.6f\n", mean, variance
        } else {
            # Default: print 1-based column index, mean, and variance.
            printf "%d\t%.6f\t%.6f\n", i, mean, variance
        }
    }
}
' "$input"
