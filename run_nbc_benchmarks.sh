#!/bin/bash

# Copyright (c) 2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -e

[[ -z "$NPROC" ]] && NPROC=2 # number of CPU cores available

REL_PATH="$(dirname ${BASH_SOURCE[0]})"

BENCHMARKS=()
if [[ -f "research/block_sim.nim" ]]; then
	BENCHMARKS+=( block_sim )
fi

make -j${NPROC} ${BENCHMARKS[*]}

for BENCH in ${BENCHMARKS[*]}; do
	build/${BENCH} > ${BENCH}_out.txt
	mkdir -p results/${BENCH}
	${REL_PATH}/process_benchmark_output.pl --type ${BENCH} --infile ${BENCH}_out.txt --outfile results/${BENCH}/result.json
done

