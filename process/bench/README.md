# Process benchmark

This package has no pure hot path to benchmark. It spawns OS processes. Process creation, OS scheduling, child execution, and pipe IO dominate the elapsed time.

## Run

There is no benchmark program or command. `process/check.bend` checks behavior. It does not measure performance.

## Input

There is no fixed benchmark input. An OS process measurement depends on the command, arguments, environment, and stdin size.

## Versions

Package: `bend-kit-process@0.4.0.0`. Sibling: `bend-kit-bytes@0.3.2.0`. No compiler or runtime version was measured for this benchmark.

## Results

No benchmark was run. There are no times or checksums to report. A cross-language spawn comparison would mainly measure OS and child-process work, not a pure Bend algorithm.
