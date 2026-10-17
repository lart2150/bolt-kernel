# Native-ARM build toolchain for the TiVo Bolt kernel (Linux 3.14.28-1.16, gcc 4.8.3).
# Runs natively on the Pi's armv7l CPU (no qemu). gcc 4.9.2 compiles the 3.14 tree cleanly.
FROM debian/eol:jessie

# jessie is archived + its signing key expired. Point at archive.debian.org (main + security -- the
# base image's installed libc6 etc. come from the security suite, so BOTH are required for a consistent
# dependency graph), mark trusted (demotes the expired-key GPG error to a warning), skip valid-until.
RUN set -eux; \
    printf 'deb [trusted=yes] http://archive.debian.org/debian jessie main\n' > /etc/apt/sources.list; \
    printf 'deb [trusted=yes] http://archive.debian.org/debian-security jessie/updates main\n' >> /etc/apt/sources.list; \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99noexpire; \
    apt-get update; \
    apt-get install -y --no-install-recommends gcc make libc6-dev bc; \
    rm -rf /var/lib/apt/lists/*
RUN gcc --version | head -1 && ld --version | head -1 && make --version | head -1 && bc --version | head -1
WORKDIR /kbuild
