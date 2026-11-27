# Storage recovery qualification

Run the process-crash matrix from the repository root:

```sh
python3 storage/crash_check.py --report /tmp/storage-crash.json
```

On macOS, add `--apfs-image` to exercise a disposable 256 MiB sparse APFS disk image. The harness creates and removes its own stores and image. It never detaches a pre-existing device or interrupts host power. It compiles native and Bun drivers with the installed Bend compiler, one compiler process at a time.

The harness copies the current storage sources to a temporary directory. It inserts checkpoints immediately before and after each `fsync`, macOS `F_FULLFSYNC`, and publication rename. It leaves the published effects unchanged and fails if an instrumentation anchor changes. A successful control run enumerates every checkpoint occurrence, including repeated closure-file and ancestor-directory barriers. Each host trial starts from a fresh store, stops the writer at one occurrence, then sends that process `SIGKILL`. It checks the signal exit and the exact checkpoint trace.

Both runtime lanes exercise object publication, absent-root creation, existing-root replacement, and a root that fences three objects left by writers killed immediately after rename. Each store has a separately acknowledged root. Recovery hashes and decodes every published object, checks every root's complete closure, and calls `Disk.checkout` in a fresh process. Interrupted roots may be old, new, or absent as appropriate; no partial published file is accepted. Exclusive temporary cleanup must acquire the released writer lock and remove the owned leftovers.

Before rename, the target must remain old or absent. A process kill after rename must leave the new target visible. After forced detach, the final completed directory barrier must preserve the new target. Earlier forced-detach outcomes do not assume rollback.

The optional image matrix force-detaches the image while the writer is stopped before rename, after rename, and after the final directory barrier. It then kills the writer, reattaches the image, and repeats recovery for the interrupted store and the completed control store. This uses `hdiutil detach -force`, without a separate unmount command. **This is not an unmount-free device removal.** macOS can unmount and flush during forced detach. The host, filesystem, image backing file, and controller stay powered.

These trials qualify process-death handling and the tested forced-detach path only. They do not simulate loss of kernel caches, torn sectors, failed cache-flush firmware, an OS crash, or real power loss. Successful `F_FULLFSYNC` calls do not certify a controller. Physical power-loss qualification still requires an approved dedicated device, safe power interruption, and post-reboot checks. Do not run that procedure on a development or shared machine.

## Recorded run: 2026-11-27

Command: `python3 storage/crash_check.py --apfs-image --report /tmp/storage-crash-report.json`.

Host: MacBook Pro `Mac16,8`, Apple M4 Pro, 48 GB RAM; macOS 26.7.2 (`25G332`), Darwin 25.6.0, arm64. The host store ran on local APFS with 4096-byte blocks. The backing device was the internal `APPLE SSD AP0512Z`, firmware `241.40.4`, through the Apple SSD Controller and Apple Fabric. The image was sparse APFS with 4096-byte blocks, through the Disk Image driver, backed by that same host volume. The controller's physical cache-flush behavior was not measured.

Runtimes: Bend 2.0.40 native and Bun 1.4.4. Barriers: real `fsync` followed by real macOS `F_FULLFSYNC` on each file and directory descriptor; atomic publication rename. No barrier was disabled or replaced with a mock.

Each row below gives the result **per runtime lane**. Native and Bun had identical counts.

| primary interruption | trials per lane | old | new | absent |
|---|---:|---:|---:|---:|
| host: object publication | 14 | 0 | 9 | 5 |
| host: root creation | 66 | 0 | 9 | 57 |
| host: root replacement | 66 | 57 | 9 | 0 |
| host: root fencing interrupted objects | 66 | 0 | 9 | 57 |
| APFS forced detach: object publication | 3 | 0 | 2 | 1 |
| APFS forced detach: root creation | 3 | 0 | 2 | 1 |
| APFS forced detach: root replacement | 3 | 1 | 2 | 0 |
| APFS forced detach: root fencing interrupted objects | 3 | 0 | 2 | 1 |

Total: 424 host interruptions and 24 forced-detach interruptions; 448 primary recovery checks passed. All 16 completed publication controls passed. Fence setup also killed 426 object writers after rename; those setup kills are not extra primary trials. Every acknowledged root and its verified closure remained readable. No partial published file, missing closure, stale writer lock, or failed temporary cleanup was observed. The oracle's negative self-check rejected a missing descendant, a bad object hash, and a partial root.

An initial harness run stopped before image trials because macOS reported `/private/var` for a `/var` mount path. The harness now resolves both paths and detaches an image if mount validation fails. The complete run above passed after that correction.

Actual host power interruptions: **0**. Reboots: **0**. Unmount-free device removals: **0**. This run is not physical power-loss qualification, including for this SSD.
