#!/usr/bin/env bash

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

This script profiles the fit_model and calibrate_fit processes for multiple countries.

Options:
  -h, --help             Show this help message and exit
  --profiler <path>      Specify the path to the profiler script (default: ./profilers/memusg)
  --fits-dir <path>      Path to directory containing model fits

Example:
  $(basename "$0") --profiler ./profilers/massif --fits-dir ~/Downloads

The script will run the profiler on fit_model and calibrate_fit for each country specified in the script.
Make sure the profiler accepts a --label flag and can be called in the same way as memusg.

EOF
    exit 0
}

# Default vars
profiler="./profilers/memusg"
fits_dir="$HOME/Downloads"

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
        --fits-dir)
            fits_dir="$2"
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

countries=("TGO" "ESW")
declare -A country_files

expanded_fit_dir=$(eval echo "$fits_dir")

# Loop through the countries and find corresponding files
for country in "${countries[@]}"; do
    # Find files in fit_dir that start with the country ISO code
    file=$(find "$expanded_fit_dir" -maxdepth 1 -type f -name "${country}*naomi_outputs.zip")

    # If a file is found, add it to the associative array
    if [[ -n "$file" ]]; then
        country_files["$country"]="$file"
    else
        echo "No file found for $country in $fits_dir"
    fi
done

echo "Using profiler $profiler"
out_dir="results/$(date +%Y%m%d_%H%M%S)"
mkdir -p out_dir
for country in "${!country_files[@]}"; do
    file="'${country_files[$country]}'"
    profile_fit "fit.$country" "$file"
    out="$out_dir/$country"
    profile_calibrate "calibrate.$country" "$file" "$out"
    calibrate_dir=$(ls "$out")
    calibrate_dir="$out/$calibrate_dir"
    if [ -d "$calibrate_dir" ]; then
        profile_download "spectrum.$country" "$calibrate_dir" "spectrum"
        profile_download "coarse_output.$country" "$calibrate_dir" "coarse_output"
        profile_download "comparison.$country" "$calibrate_dir" "comparison"
        profile_download "summary.$country" "$calibrate_dir" "summary"
        profile_download "agyw.$country" "$calibrate_dir" "agyw"
    else
        echo "Calibration directory for $country does not exist. Skipping downloads"
    fi
done
