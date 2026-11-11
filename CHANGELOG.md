# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-11

### Added
- `cve-scan`: scans the crunchtools image fleet with grype (local podman store
  first, registry fallback) and writes a facts-only `cve.status` the
  `nagios-agent` check reads. The vulnerability DB lives on a volume and is
  refreshed every run; `db_built` records the real DB build date so a failed
  refresh never looks fresh. An unscannable image is recorded `result=error`,
  never dropped; an empty fleet list is refused rather than written as a false
  green.
- `cve-classify`: turns one grype JSON report into a single line of counts
  (severity + `fix.state` + `rce`). The v1 page tier is fixable Critical; `rce`
  is carried over all criticals with a network vector so a later check-side
  tightening needs no rescan.
- `fleet-images.conf`: the scan target list, including the oneshots (grype,
  deployer) a running-containers scan would miss; overridable by a host mount.
- Container image on ubi10-minimal with a pinned grype release; `grype.env.example`
  and a oneshot unit template for the gloval deployment.

[Unreleased]: https://github.com/crunchtools/grype/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/crunchtools/grype/releases/tag/v0.1.0
