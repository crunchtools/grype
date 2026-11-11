# grype

Scheduled CVE scanner for the crunchtools image fleet — the runtime replacement
for the per-repo build-time Trivy gate ([RT #1551](https://acquacotta.crunchtools.com/#rt/ticket/1551)).

`pip-audit` already catches Python dependency CVEs at build time. What nothing
watched was **base-image / OS-package CVEs on the published images**, and the
**rebuild drift** that freezes an image weeks behind its errata. Quay's own Clair
scanner returns `unsupported` for our public repos, so there is no registry
verdict to read — this image runs [grype](https://github.com/anchore/grype)
itself and writes a status file the Nagios check judges.

## How it works

```
Kagetora (every 6h) ──starts──▶ grype.crunchtools.com.service (oneshot)
                                      │  cve-scan
                                      │  • grype db update   (DB on a volume)
                                      │  • scan each fleet image (local store
                                      │    first, registry fallback)
                                      │  • classify: severity + fix.state + rce
                                      ▼
                                 cve.status  ──read──▶ nagios-agent
                                                       check_image_cve.sh
                                                       OK / WARNING / CRITICAL
```

The scanner **calls no model and makes no decisions** — it counts; the Nagios
check routes. Routing (deterministic, so no model wakes to triage):

| Finding | Verdict | Action |
|---|---|---|
| unfixable only (no upstream fix) | OK | nothing — `.trivyignore` owns these |
| stale, or a **fixable High** | WARNING | rebuild within 6h |
| a **fixable Critical** | CRITICAL | page, and rebuild |
| DB older than 48h, missing file, image absent | UNKNOWN | notify |

## Two verbs, one image

- `cve-scan` — the detector above. Holds no write credential.
- `rebuilder` *(later)* — acts on findings (files Rebuild tickets, dispatches
  builds). Runs as its **own unit with its own credentials**; a scanner that can
  read images should not also hold a token that can write.

## `cve.status` format

```
CVE generated=<epoch> db_built=<epoch> db_age_days=<n> db_updated=<0|1> images=<n> elapsed=<s>
CVE item=<ref> seen=<epoch> result=ok source=<podman|registry> total=.. crit=.. high=.. med=.. fix_crit=.. fix_high=.. unfix=.. rce=..
CVE item=<ref> seen=<epoch> result=error msg=<text>
CVE end=1
```

`db_built` is the DB's real build date, not the scan time: a failed refresh
leaves it old on purpose so the check catches a stale scanner. An image that
cannot be scanned is `result=error`, never dropped.

## Development

```
tests/test_classify.sh          # classifier unit tests (bash + jq, no grype)
podman build -f Containerfile .  # build the image
```

The fleet list is `fleet-images.conf`; on gloval the unit mounts the host's
authoritative list over it. Licensed AGPL-3.0-or-later.
