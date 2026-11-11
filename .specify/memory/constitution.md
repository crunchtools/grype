# grype Constitution

> **Version:** 1.0.0
> **Ratified:** 2026-11-11
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.39.3
> **Profile:** Container Image

## What this image provides

A scheduled CVE scanner for the crunchtools image fleet (RT #1551), the runtime
replacement for the per-repo build-time Trivy gate. It wraps
[anchore/grype](https://github.com/anchore/grype): `cve-scan` reads the fleet
list, scans each image, and writes a facts-only `cve.status` that the
`nagios-agent` `check_image_cve.sh` plugin reads and routes on. The scanner
calls no model and makes no decisions — it counts; the Nagios check judges.

A later verb (`rebuilder`) ships in this same image, run by its own unit with
its own credentials, to act on findings. One image, two verbs, two units.

## Base image and packages

- `registry.access.redhat.com/ubi10/ubi-minimal` — the wrapper is bash, so this
  is not a distroless base. `jq` (parse grype JSON), `tar`/`gzip` (extract the
  grype release), `ca-certificates` (TLS to the registry and the DB endpoint).
- The `grype` binary is installed from a pinned release asset (`GRYPE_VERSION`),
  never `curl | sh`.

## Project-unique requirements

- **The vulnerability DB is never baked into the image.** It lives on a volume
  (`/var/cache/grype`) and is refreshed at the start of every run. A scanner
  shipping a frozen DB is the staleness failure this project exists to catch,
  built into the one thing meant to catch it.
- **A failed DB refresh must never produce a fresh-looking status.** `cve.status`
  records the DB's real build date (`db_built`), not the scan time; the Nagios
  check goes UNKNOWN when it is too old.
- **No image is silently dropped.** An image that cannot be scanned is recorded
  `result=error`, never omitted — a silent gap is the one failure a fleet
  scanner must not have.
- **The scanner holds no write credential and runs no model.** It reads images
  and writes a local file. Acting on findings (filing tickets, dispatching
  rebuilds) is the `rebuilder` verb's job, under its own separate credentials.
