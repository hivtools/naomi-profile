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
  echo "Profiling fit for $label"
  "$profiler" --label "$label" ./fit_model "$file"
  echo "Completed fit for $label"
}

profile_calibrate() {
  label=$1
  file=$2
  results_dir=$3
  echo "Profiling calibrate for $label"
  "$profiler" --label "$label" ./calibrate_fit "$file" "$results_dir"
  echo "Completed calibrate for $label"
}

profile_download() {
  label=$1
  file=$2
  type=$3
  echo "Profiling download for $label"
  "$profiler" --label "$label" ./generate_download "$file" "$type"
  echo "Completed download for $label"
}

declare -A country_files=(
    ["TGO"]='"~/Downloads/TGO 2024 naomi_outputs.zip"'
    ["ESW"]='"~/Downloads/ESW 2024 naomi_outputs.zip"'
)

echo "Using profiler $profiler"
out_dir="results"
for country in "${!country_files[@]}"; do
    file="${country_files[$country]}"
    profile_fit "fit.$country" "$file"
    out="$out_dir/$country"
    profile_calibrate "calibrate.$country" "$file" "$out"
    calibrate_dir=$(ls "$out")
    calibrate_dir="$out/$calibrate_dir"
    profile_download "spectrum.$country" "$calibrate_dir" "spectrum"
    profile_download "coarse_output.$country" "$calibrate_dir" "coarse_output"
    profile_download "comparison.$country" "$calibrate_dir" "comparison"
    profile_download "summary.$country" "$calibrate_dir" "summary"
done
