#!/usr/bin/env bash

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

This script profiles the fit_model and calibrate_fit processes for multiple countries.

Options:
  -h, --help             Show this help message and exit
  --profiler <path>      Specify the path to the profiler script (default: ./profilers/memusg)

Example:
  $(basename "$0") --profiler ./profilers/massif

The script will run the profiler on fit_model and calibrate_fit for each country specified in the script.
Make sure the profiler accepts a --label flag and can be called in the same way as memusg.

EOF
    exit 0
}

# Default profiler
profiler="./profilers/memusg"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        --profiler)
            profiler="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Check if the profiler exists and is executable
if [[ ! -x "$profiler" ]]; then
    echo "Error: Profiler '$profiler' not found or not executable." >&2
    exit 1
fi


profile_fit() {
  label=$1
  file=$2
  "$profiler" --label "$label" ./fit_model "$file"
}

profile_calibrate() {
  label=$1
  file=$2
  "$profiler" --label "$label" ./calibrate_fit "$file"
}

declare -A country_files=(
    ["TGO"]='"~/Downloads/TGO 2024 naomi_outputs.zip"'
    ["ESW"]='"~/Downloads/ESW 2024 naomi_outputs.zip"'
)

echo "Using profiler $profiler"
for country in "${!country_files[@]}"; do
    file="${country_files[$country]}"
    echo "Profiling fit for $country"
    profile_fit "fit.$country" "$file"
    echo "Completed fit $country"
    echo "Profiling calibration for $country"
    profile_calibrate "calibrate.$country" "$file"
    echo "Completed calibrate $country"
done
