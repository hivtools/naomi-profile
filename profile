#!/usr/bin/env bash


profile_fit() {
  label=$1
  file=$2
  ./profilers/memusg --label "$label" ./fit_model "$file"
}

profile_calibrate() {
  label=$1
  file=$2
  ./profilers/memusg --label "$label" ./calibrate_fit "$file"
}

declare -A country_files=(
    ["TGO"]='"~/Downloads/TGO 2024 naomi_outputs.zip"'
    ["ESW"]='"~/Downloads/ESW 2024 naomi_outputs.zip"'
)

for country in "${!country_files[@]}"; do
  file="${country_files[$country]}"
  echo "Profiling fit for $country"
  profile_fit "fit.$country" "$file"
  echo "Completed fit $country"
  echo "Profiling calibration for $country"
  profile_calibrate "calibrate.$country" "$file"
  echo "Completed calibrate $country"
done
