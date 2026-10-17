#!/bin/bash
# One-time prepare of the TiVo Bolt kernel tree (stblinux-3.14-1.16) for out-of-tree module builds.
# Builds the toolchain image if missing, applies patches/, configures, modules_prepare.
set -e
cd "$(dirname "$0")"
REPO=$PWD
. ./env.sh

[ -f $KTREE/Makefile ] || git submodule update --init stblinux
# host networking: under WSL the DNS stub isn't reachable from the default bridge
$DOCKER image inspect "$IMAGE" >/dev/null 2>&1 || \
  $DOCKER build --network host --build-arg UARCH=$UARCH -t "$IMAGE" docker/

# tivo-layout: TiVo struct padding (request/request_queue/task_struct); cifs-no-keys: device has no KEYS
for p in patches/*.patch; do
  if patch -d $KTREE -p1 -R -s -f --dry-run < "$p" >/dev/null 2>&1; then
    echo "$(basename "$p") already applied"
  else
    patch -d $KTREE -p1 -N --no-backup-if-mismatch < "$p"
  fi
done

# the prepared tree holds host binaries and compiler-dependent output: clean it if it was
# prepared on another host arch or with another toolchain image
STAMP="$(uname -m) $($DOCKER image inspect -f '{{.Id}}' "$IMAGE")"
CLEAN=
[ -f $KTREE/.bolt-host ] && [ "$(cat $KTREE/.bolt-host)" != "$STAMP" ] && CLEAN="make mrproper"

$DOCKER run --rm --user $(id -u):$(id -g) -e HOME=/tmp -e CROSS_COMPILE=$CROSS_COMPILE \
    -v "$REPO":/kbuild "$IMAGE" bash -c "
  set -e; cd /kbuild/$KTREE; export ARCH=arm HOME=/tmp
  $CLEAN
  make -j\$(nproc) brcmstb_defconfig >/dev/null 2>&1
  cat /kbuild/config/bolt_fragment.config >> .config
  make -j\$(nproc) olddefconfig >/dev/null 2>&1
  make -j\$(nproc) modules_prepare
  cp /kbuild/symvers/Module.symvers.device ./Module.symvers
  echo PREPARED: \$(sed -n 's/.*\"\(.*\)\"/\1/p' include/generated/utsrelease.h) with \$(\${CROSS_COMPILE}gcc --version | head -1)
"
echo "$STAMP" > $KTREE/.bolt-host
