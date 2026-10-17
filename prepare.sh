#!/bin/bash
# One-time prepare of the TiVo Bolt kernel tree (stblinux-3.14-1.16) for out-of-tree module builds.
# Builds the toolchain image if missing, applies the TiVo struct-layout patch, configures, modules_prepare.
set -e
cd "$(dirname "$0")"
REPO=$PWD
DOCKER=${DOCKER:-sudo docker}
IMAGE=${IMAGE:-tivo-kbuild:3.14}

[ -f stblinux/linux/Makefile ] || git submodule update --init stblinux
$DOCKER image inspect "$IMAGE" >/dev/null 2>&1 || $DOCKER build -t "$IMAGE" docker/

# tivo-layout: TiVo struct padding (request/request_queue/task_struct); cifs-no-keys: device has no KEYS
for p in patches/*.patch; do
  if patch -d stblinux/linux -p1 -R -s -f --dry-run < "$p" >/dev/null 2>&1; then
    echo "$(basename "$p") already applied"
  else
    patch -d stblinux/linux -p1 -N --no-backup-if-mismatch < "$p"
  fi
done

$DOCKER run --rm --user $(id -u):$(id -g) -e HOME=/tmp -v "$REPO":/kbuild "$IMAGE" bash -c "
  set -e; cd /kbuild/stblinux/linux; export ARCH=arm HOME=/tmp
  make -j\$(nproc) brcmstb_defconfig >/dev/null 2>&1
  cat /kbuild/config/bolt_fragment.config >> .config
  make -j\$(nproc) olddefconfig >/dev/null 2>&1
  make -j\$(nproc) modules_prepare
  cp /kbuild/symvers/Module.symvers.device ./Module.symvers
  echo PREPARED: \$(sed -n 's/.*\"\(.*\)\"/\1/p' include/generated/utsrelease.h)
"
