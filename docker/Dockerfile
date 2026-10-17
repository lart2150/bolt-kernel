# Ubuntu 14.10 (utopic) toolchain for the TiVo Bolt kernel: gcc 4.8.3, the device kernel's own version
# ("gcc version 4.8.3 (GCC)"). Same compiler on both host types:
#   --build-arg UARCH=amd64  ->  x86_64 host, cross gcc-4.8-arm-linux-gnueabihf 4.8.3-12ubuntu3
#   --build-arg UARCH=armhf  ->  armv7l host (Pi), native gcc-4.8 4.8.3-12ubuntu3
# Docker 29 can't pull ubuntu:14.10 (v1 manifest), so start from the official ubuntu-core rootfs.
# Hashes are from SHA256SUMS signed by the Ubuntu CD Image key C5986B4F1257FFA86632CBA746181433FBB75451.
FROM busybox:1.36 AS rootfs
ARG UARCH=amd64
RUN set -e; \
    case "$UARCH" in \
      amd64) sum=9d15da162fd90994b0dc25963a5c42f829c6eb2c3b4a3d7d634a504906c4fe4e ;; \
      armhf) sum=107a8e9ea989dc950cdd8b1addba54c17c4c068e115e7b46587a6cc586e694ea ;; \
      *) echo "UARCH must be amd64 or armhf"; exit 1 ;; \
    esac; \
    for i in 1 2 3; do wget -q -T 60 -O /core.tgz http://old-releases.ubuntu.com/releases/ubuntu-core/releases/14.10/release/ubuntu-core-14.10-core-$UARCH.tar.gz && break; sleep 5; done; \
    echo "$sum  /core.tgz" | sha256sum -c -; \
    mkdir /rootfs; tar -xzf /core.tgz -C /rootfs --exclude=./dev; rm /core.tgz

FROM scratch
ARG UARCH=amd64
COPY --from=rootfs /rootfs /
RUN set -eux; \
    printf 'deb http://old-releases.ubuntu.com/ubuntu utopic main universe\ndeb http://old-releases.ubuntu.com/ubuntu utopic-updates main universe\ndeb http://old-releases.ubuntu.com/ubuntu utopic-security main universe\n' > /etc/apt/sources.list; \
    # some old-releases backends drop or stall connections (a whole IPv6 site, one IPv4 address seen
    # 2026-10); apt's default has no timeout and hung for 10+ min. IPv4 + timeout + retries copes.
    printf 'Acquire::ForceIPv4 "true";\nAcquire::Retries "5";\nAcquire::http::Timeout "60";\n' > /etc/apt/apt.conf.d/99net; \
    apt-get update; \
    if [ "$UARCH" = amd64 ]; then x="gcc-4.8-arm-linux-gnueabihf binutils-arm-linux-gnueabihf"; else x=binutils; fi; \
    apt-get install -y --no-install-recommends gcc-4.8 make libc6-dev bc $x; \
    ln -sf gcc-4.8 /usr/bin/gcc; \
    [ "$UARCH" = amd64 ] && ln -sf arm-linux-gnueabihf-gcc-4.8 /usr/bin/arm-linux-gnueabihf-gcc; \
    rm -rf /var/lib/apt/lists/*
ENV ARCH=arm
WORKDIR /kbuild
