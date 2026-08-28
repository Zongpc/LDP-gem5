# MICRO 2026 Artifact Evaluation Guide

The permanent archive is available through
<https://doi.org/10.5281/zenodo.21502244>.

## 1. What the artifact evaluates

This artifact provides a compact reproduction of the performance trend in
Fig. 18 of the paper *Loop-Decoupled Prefetcher for Linked Data Structure* and
a mechanism-level loop-decoupling ablation corresponding to Fig. 24.

The nine tasks cover:

- BFS, MST, and SSSP with the `cage10` and `sx-superuser` graph inputs;
- hash join probe with 1.28M build and probe tuples;
- group-by with 1.28M input tuples; and
- IPv4 lookup with 100,000 entries.

Each restored simulation uses the `O3_ARM_Neoverse_v2` CPU profile and
DDR5-6400 memory. The `fast` profile uses 10-million-instruction windows,
except that GB uses 60 million instructions to include its relevant later
phase. The `full` profile runs every workload to normal completion.

The compact artifact does not evaluate the other prefetchers or the full
13-application suite used in the paper. It is intended to reproduce the
no-prefetch versus LDP trend and directly test the paper's loop-decoupling
mechanism.

## 2. Components

- `src/mem/cache/prefetch/ldp.{cc,hh}`: LDP implementation.
- `configs/ldp/se.py`: ARM syscall-emulation configuration.
- `tasks/tasks.conf`: fixed task definitions.
- `workloads/`: AArch64 binaries and graph inputs.
- `scripts/reproduce.py`: one-command run, analysis, plot, and validation.
- `scripts/run.py`: lower-level checkpoint and simulation runner.
- `scripts/validate*.py`: comparison with profile-specific references.
- `expected/`: read-only reference data for the archived profiles.
- `checkpoints/`: supplied in the Docker image and archive runtime bundle.

Generated files are never written under `expected/`. Native and Docker runs
place all outputs under `results/<profile>/`.

## 3. Resource requirements

No special CPU, GPU, FPGA, kernel module, performance counter, or proprietary
software is required. The host executes an ARM target through gem5, so the
recommended host is x86-64 Linux with Docker Engine.

Four CPU cores are sufficient; additional cores increase simulation
parallelism. In local validation with 12 workers, the three-configuration
`fast` and `full` profiles completed in approximately 11 and 28 minutes,
respectively. Runtime varies with host CPU and the selected `--jobs` value.

## 4. Docker workflow

Pull the evaluated image:

```bash
docker pull ghcr.io/zongpc/ldp-gem5:micro26-final
```

The recommended launchers do not bind-mount a host directory while gem5 is
running:

```bash
# Linux, macOS, or WSL
./scripts/run-docker.sh fast

# Windows PowerShell
.\scripts\run-docker.ps1 -Profile fast
```

They use a unique container name and keep the stopped container until export
succeeds. On a fresh checkout, output goes to `results/fast`. If `results`
already exists, the launcher selects a fresh timestamped directory instead
of merging with stale or root-owned files. Set `RESULTS_DIR=new-results` on
POSIX, or `-OutputDir new-results` in PowerShell, to choose another new path.

The workflow runs no-prefetching, LDP without loop decoupling, and full LDP
for all nine tasks. It then:

1. reports task, application, and overall LDP speedups;
2. validates the speedup reproduction;
3. validates the loop-decoupling ablation; and
4. generates `results/fast/analysis/mechanism.png`.

The final success messages include:

```text
VALIDATION PASSED: 9 task(s)
MECHANISM REPRODUCTION PASSED
[CHECK PASSED] SPEEDUP REPRODUCTION PASSED
[CHECK PASSED] LOOP DECOUPLING IS EFFECTIVE
[EVIDENCE] Overall speedup: ... without loop decoupling -> ... with full LDP
```

The runner displays the final three lines in a prominent green banner and
only prints them after both validations pass. `docker cp` exports the PNG with
the other results, so no graphical environment is needed in the container.

Run the completion-based profile in its own profile directory:

```bash
./scripts/run-docker.sh full
# PowerShell: .\scripts\run-docker.ps1 -Profile full
```

### Output-permission portability

An earlier bind-mount command could fail when the image user and host user had
different UID/GID values. Passing a POSIX `--user` mapping does not solve the
same problem on Windows Docker Desktop, whose Git Bash UID is not a Linux host
UID. The default create/start/copy workflow avoids this mismatch entirely:
gem5 writes to the image-owned `/results`, and the Docker daemon copies the
finished files to a newly created host directory afterward. The host working
directory itself must still permit the invoking user to create a new folder.

If a completed container was retained after an export error, do not rerun the
simulations. Export it to a new sibling directory:

```bash
OUTPUT="ldp-results-$(date +%Y%m%d-%H%M%S)"
mkdir "$OUTPUT"
docker cp <container-name>:/results/. "$OUTPUT/"
docker rm <container-name>
```

For advanced POSIX use, a bind mount remains supported when the container is
mapped to the host user:

```bash
mkdir -p results
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD/results:/results" "$IMAGE" --run-profile fast --jobs 4
```

Do not use this UID/GID form from Windows Git Bash or PowerShell. Prefer the
provided PowerShell launcher; a Docker named volume is another portable
alternative for repeated runs.

## 5. Native workflow

Install dependencies and build gem5:

```bash
sudo apt-get update
sudo apt-get install -y build-essential scons python3.10-dev python3-pil \
  fonts-dejavu-core zlib1g-dev m4 pkg-config
source sourceme
PYTHON_CONFIG=python3.10-config \
CCFLAGS_EXTRA='-include stdint.h' \
scons build/ARM_LDP/gem5.opt -j"$(nproc)"
```

Without packaged checkpoints, the runner first executes the workload's
built-in checkpoint phase and stores the resulting checkpoint under
`results/fast/<task>/`. Run the complete workflow with:

```bash
python3 scripts/reproduce.py --run-profile fast --jobs 4
```

With the archive checkpoint bundle:

```bash
python3 scripts/reproduce.py \
  --checkpoint-root /path/to/checkpoints \
  --run-profile fast --jobs 4
```

The native workflow presents evaluation as two result substeps:

1. **Overall speedup:** `speedup.csv` and `summary.txt` compare full LDP with
   no-prefetching and report task, application, and overall speedups.
2. **Loop-decoupling ablation:** `mechanism.csv`,
   `mechanism_summary.csv`, and `mechanism.png` compare full LDP with the same
   prefetcher after disabling only loop decoupling.

Both substeps are generated and validated by `scripts/reproduce.py`; no
separate analysis command is required.

## 6. Outputs and interpretation

Each task directory records the actual gem5 commands, simulator logs, and
statistics for:

- `nopf_restored`: no-prefetch baseline;
- `ldp_no_loop_restored`: LDP without loop decoupling; and
- `ldp_restored`: full LDP.

The analysis directory contains:

- `speedup.csv` and `summary.txt`: overall performance reproduction;
- `mechanism.csv` and `mechanism_summary.csv`: auditable ablation data;
- `mechanism_validation.txt`: collection checks; and
- `mechanism.png`: Fig. 24-style visualization.

The `fast` profile is intended for timely functional and trend validation.
Running to completion gives LDP more opportunities to act in later workload
phases: the `full` profile therefore shows a substantially stronger aggregate
benefit and more closely follows the full-execution trend in the paper. Fast
and full results are kept separate and must not be combined into one mean.

## 7. IPv4 note

Under the AE configuration, IPv4 without loop decoupling identifies only the
outermost streaming access. Those few requests are almost always timely, so
the reported timeliness is close to 100%; however, the prefetcher issues very
few requests, coverage is nearly zero, and the configuration provides almost
no speedup. Enabling loop decoupling exposes the complete dependent access
relation, allowing LDP to issue the useful linked-data-structure prefetches
while retaining high timeliness and achieving a clear speedup.

This illustrates why timeliness alone does not imply effectiveness when the
mechanism covers almost none of the target accesses.

## 8. Customization and troubleshooting

`scripts/reproduce.py --help` lists the supported profile, checkpoint,
parallelism, and task controls. `scripts/run.py --help` exposes lower-level
collection and CPU-profile options. Results from custom instruction limits or
CPU profiles are exploratory and should not be compared with the archived
references.

- `gem5 binary not found`: use the Docker image or complete the native build.
- `Missing checkpoint(s)`: verify one `cpt.*` directory containing `m5.cpt`
  under each selected task.
- `VALIDATION FAILED`: inspect the named task's stats and simulator log.
- Docker permission errors: retain the UID/GID mapping and verify that the
  bind-mounted host directory is writable.

Report evaluation problems through the
[GitHub issue tracker](https://github.com/Zongpc/LDP-gem5/issues) and
include the image digest, host OS, command, and failing task log.
