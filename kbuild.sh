#!/bin/bash
# Build an out-of-tree kernel module for the TiVo Bolt (Linux 3.14.28-1.16).
# Usage: ./kbuild.sh <module-dir> [make args...]     e.g.  ./kbuild.sh mod/hello
set -e
MODDIR="$(realpath "${1:?usage: kbuild.sh <module-dir> [make args]}")"; shift
cd "$(dirname "$0")"
REPO=$PWD
. ./env.sh
[ -f "$MODDIR/Makefile" ] || [ -f "$MODDIR/Kbuild" ] || { echo "no Makefile/Kbuild in $MODDIR"; exit 1; }
STAMP="$(uname -m) $($DOCKER image inspect -f '{{.Id}}' "$IMAGE" 2>/dev/null)"
[ "$(cat $KTREE/.bolt-host 2>/dev/null)" = "$STAMP" ] || { echo "tree not prepared for this host/toolchain -> run ./prepare.sh"; exit 2; }
$DOCKER run --rm --user $(id -u):$(id -g) -e HOME=/tmp -e CROSS_COMPILE=$CROSS_COMPILE \
    -v "$REPO":/kbuild -v "$MODDIR":/mod "$IMAGE" bash -c "
  set -e; cd /kbuild/$KTREE; export ARCH=arm HOME=/tmp
  [ -f Module.symvers ] || cp /kbuild/symvers/Module.symvers.device ./Module.symvers
  make -j\$(nproc) M=/mod modules $*
"
echo "built:"; ls -l "$MODDIR"/*.ko 2>/dev/null
