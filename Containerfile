# grype — the crunchtools fleet CVE scanner (RT #1551).
#
# A thin wrapper around anchore/grype: /usr/local/bin/cve-scan reads the fleet
# list, scans each image, and writes a facts-only cve.status the Nagios check
# reads. The vulnerability DB is NOT baked in — it lives on a volume and is
# refreshed every run (a scanner with a stale DB is the hermes failure in a new
# place). ubi10-minimal, not a distroless base: the wrapper is bash.

FROM registry.access.redhat.com/ubi10/ubi-minimal:latest

# grype release to install. Dependabot bumps this (see .github/dependabot.yml
# docker ecosystem); the pin fixes the binary for the build and for CI.
ARG GRYPE_VERSION=0.121.3

LABEL maintainer="fatherlinux <scott.mccarty@crunchtools.com>"
LABEL description="Scheduled CVE scanner for the crunchtools image fleet: runs grype per image and writes a status file the Nagios check reads (RT #1551)."
LABEL org.opencontainers.image.source="https://github.com/crunchtools/grype"
LABEL org.opencontainers.image.licenses="AGPL-3.0-or-later"

# jq parses grype's JSON; tar/gzip extract the grype release; ca-certificates
# lets grype reach the registry and the DB endpoint over TLS.
RUN microdnf install -y jq tar gzip ca-certificates shadow-utils \
    && microdnf clean all

# Install the pinned grype binary from its release asset (no curl | sh).
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64)  arch=amd64 ;; \
        aarch64) arch=arm64 ;; \
        *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -sSfL -o /tmp/grype.tgz \
        "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_${arch}.tar.gz"; \
    tar -xzf /tmp/grype.tgz -C /usr/local/bin grype; \
    rm -f /tmp/grype.tgz; \
    grype version

COPY rootfs/ /
COPY fleet-images.conf /etc/grype/fleet-images.conf

# The DB cache and the status output are the two things that must survive and be
# shared with the host; both are volumes the unit binds to persistent paths.
ENV GRYPE_DB_CACHE_DIR=/var/cache/grype \
    STATE_DIR=/var/lib/grype-scan \
    FLEET_CONF=/etc/grype/fleet-images.conf \
    GRYPE_BIN=grype \
    CLASSIFY_BIN=cve-classify
RUN mkdir -p /var/cache/grype /var/lib/grype-scan
VOLUME ["/var/cache/grype", "/var/lib/grype-scan"]

# No hard ENTRYPOINT: this image carries two verbs run by two different units
# (cve-scan now; the rebuilder later). The unit's ExecStart names the one it
# wants. The boot gate runs `grype version`.
CMD ["cve-scan"]
