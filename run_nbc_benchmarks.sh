#!/bin/bash

# Copyright (c) 2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -e

# OS detection
if uname | grep -qi darwin; then
  # macOS
  MAX_NPROC="$(sysctl -n hw.logicalcpu)"
  GETOPT_BINARY="/usr/local/opt/gnu-getopt/bin/getopt"
  [[ -f "$GETOPT_BINARY" ]] || { echo "GNU getopt not installed. Please run 'brew install gnu-getopt'. Aborting."; exit 1; }
else
  MAX_NPROC="$(nproc)"
  GETOPT_BINARY="getopt"
fi

if uname | grep -qiE "mingw|msys"; then
  # Windows
  MAKE_CMD=mingw32-make
else
  MAKE_CMD=make
fi

if [[ -z "${MAKE}" ]]; then
  MAKE=${MAKE_CMD}
fi

# argument parsing
! ${GETOPT_BINARY} --test > /dev/null
if [ ${PIPESTATUS[0]} != 4 ]; then
  echo '`getopt --test` failed in this environment.'
  exit 1
fi

OPTS="h"
LONGOPTS="help,jobs:,output-type:"

# default values
NPROC="${MAX_NPROC}"
OUTPUT_TYPE="jenkins"

print_help() {
  cat <<EOF
Usage: $(basename "$0") --jobs <number of parallel build jobs> --output-type <jenkins|d3>

  -h, --help                  this help message
  --jobs                      number of parallel build jobs (default: ${NPROC})
  --output-type               output type ("jenkins" or "d3"; default: ${OUTPUT_TYPE})
EOF
}

! PARSED=$(${GETOPT_BINARY} --options=${OPTS} --longoptions=${LONGOPTS} --name "$0" -- "$@")
if [ ${PIPESTATUS[0]} != 0 ]; then
  # getopt has complained about wrong arguments to stdout
  exit 1
fi

# read getopt's output this way to handle the quoting right
eval set -- "$PARSED"
while true; do
  case "$1" in
    -h|--help)
      print_help
      exit
      ;;
    --jobs)
      NPROC="$2"
      shift 2
      ;;
    --output-type)
      OUTPUT_TYPE="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "argument parsing error"
      print_help
      exit 1
  esac
done

# benchmarking

REL_PATH="$(dirname ${BASH_SOURCE[0]})"

BENCHMARKS=()
if [[ -f "research/block_sim.nim" ]]; then
  BENCHMARKS+=( block_sim )
fi
if [[ -f "research/state_sim.nim" ]]; then
  BENCHMARKS+=( state_sim )
fi

"${MAKE}" -j${NPROC} NIMFLAGS="-f" --no-print-directory ${BENCHMARKS[*]}

if [[ ${OUTPUT_TYPE} == "jenkins" ]]; then
  OUT_DIR="."
  MSG=( "\nJenkins benchmark results generated." )
elif [[ ${OUTPUT_TYPE} == "d3" ]]; then
  OUT_DIR="benchmark_results"
  mkdir -p ${OUT_DIR}
  MSG=( "\nYou can open the following URLs in your browser:" )
fi

for BENCH in ${BENCHMARKS[*]}; do
  echo -n "Running ${BENCH} benchmarks..."
  build/${BENCH} > "${OUT_DIR}/${BENCH}_out.txt"
  echo
  # process the benchmark results
  if [[ ${OUTPUT_TYPE} == "jenkins" ]]; then
    mkdir -p results/${BENCH}
    ${REL_PATH}/process_benchmark_output.pl \
      --type ${BENCH} \
      --infile "${OUT_DIR}/${BENCH}_out.txt" \
      --output-type "${OUTPUT_TYPE}" \
      --outfile results/${BENCH}/result.json
  elif [[ ${OUTPUT_TYPE} == "d3" ]]; then
    mkdir -p "${OUT_DIR}"
    ${REL_PATH}/process_benchmark_output.pl \
      --type ${BENCH} \
      --infile "${OUT_DIR}/${BENCH}_out.txt" \
      --output-type "${OUTPUT_TYPE}" \
      --outdir "${OUT_DIR}"
    sed \
      -e "s/%BENCH_NAME%/${BENCH}/g" \
      ${REL_PATH}/template.html > "${OUT_DIR}/${BENCH}.html"
    MSG+=( "file://$(pwd)/${OUT_DIR}/${BENCH}.html" )
  fi
done

for LINE in "${MSG[@]}"; do
  echo -e "${LINE}"
done

