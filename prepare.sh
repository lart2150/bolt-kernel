#!/bin/bash
# One-time prepare of the TiVo Bolt kernel tree (stblinux-3.14-1.16) for out-of-tree module builds.
# Builds the toolchain image if missing, applies patches/, configures, modules_prepare.
set -e
cd "$(dirname "$0")"
REPO=$PWD
. ./env.sh

[ -f $KTREE/Makefile ] || git submodule update --init stblinux
# host networking: under WSL the DNS stub isn't reachable from the default bridge
$DOCKER image inspect "$IMAGE" >/dev/null 2>&1 || $DOCKER build --network host -t "$IMAGE" -f $DOCKERFILE docker/

# tivo-layout: TiVo struct padding (request/request_queue/task_struct); cifs-no-keys: device has no KEYS
for p in patches/*.patch; do
  if patch -d $KTREE -p1 -R -s -f --dry-run < "$p" >/dev/null 2>&1; then
    echo "$(basename "$p") already applied"
  else
    patch -d $KTREE -p1 -N --no-backup-if-mismatch < "$p"
  fi
done

# scripts/ holds host binaries: a tree prepared on another host arch must be cleaned first
CLEAN=
[ -f $KTREE/.bolt-host ] && [ "$(cat $KTREE/.bolt-host)" != "$(uname -m)" ] && CLEAN="make mrproper"

$DOCKER run --rm --user $(id -u):$(id -g) -e HOME=/tmp -v "$REPO":/kbuild "$IMAGE" bash -c "
  set -e; cd /kbuild/$KTREE; export ARCH=arm HOME=/tmp
  $CLEAN
  make -j\$(nproc) brcmstb_defconfig >/dev/null 2>&1
  cat /kbuild/config/bolt_fragment.config >> .config
  make -j\$(nproc) olddefconfig >/dev/null 2>&1
  make -j\$(nproc) modules_prepare
  cp /kbuild/symvers/Module.symvers.device ./Module.symvers
  echo PREPARED: \$(sed -n 's/.*\"\(.*\)\"/\1/p' include/generated/utsrelease.h) with \${CROSS_COMPILE}gcc \$(\${CROSS_COMPILE}gcc -dumpversion)
"
uname -m > $KTREE/.bolt-host
