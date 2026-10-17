# bolt-kernel

Build environment for **out-of-tree loadable kernel modules** for the TiVo Bolt
(kernel `3.14.28-1.16`, ARMv7 Brahma-B15). Produces `.ko`s that pass the box's
`vermagic` + `modversions` checks *and* match its struct layouts.

```
vermagic = 3.14.28-1.16 SMP mod_unload modversions ARMv7 p2v8
```

Tested live: fuse (sshfs), cifs (SMB3 + md4/md5/hmac/arc4/ecb/cmac), xpad (input,
rumble, LEDs), plus hello/chrdev smoke tests.

## Layout

| Path | What |
|---|---|
| `stblinux/` | submodule: Broadcom stblinux-3.14 @ tag `stblinux-3.14-1.16` (kernel under `linux/`) |
| `docker/Dockerfile` | `debian/eol:jessie` + gcc 4.9.2 (the box was built with gcc 4.8.3; host gcc is too new for 3.14) |
| `config/bolt_fragment.config` | appended to `brcmstb_defconfig` — every line is there to match the device's struct layouts |
| `patches/tivo-layout.patch` | pads `struct request` / `request_queue` / `task_struct` to the TiVo offsets |
| `patches/cifs-no-keys.patch` | drops cifs's `select KEYS` (device kernel has no keyring) |
| `symvers/Module.symvers.device` | the device's full export CRC table (5845 symbols), extracted from the kernel Image |
| `prepare.sh` | one-time: build image, apply patch, configure, `modules_prepare` |
| `kbuild.sh <dir>` | build a module dir against the prepared tree |
| `verify.py <ko>` | vermagic + CRC + undefined-symbol go/no-go against the device table |
| `mod/hello/` | smoke-test module |

## Usage

Designed for an **armv7l host** (a Pi 4 booted 32-bit) so the build is native — no
cross-compiler. Needs docker, `patch`, and binutils (`arm-linux-gnueabihf-objcopy`/`-nm`
for `verify.py`).

```bash
git clone --recurse-submodules https://github.com/lart2150/bolt-kernel.git
cd bolt-kernel
./prepare.sh                     # once (or after re-checking-out stblinux)
./kbuild.sh mod/hello            # -> mod/hello/hello.ko
./verify.py mod/hello/hello.ko   # WILL LOAD ON BOLT: YES
```

Docker is invoked as `sudo docker` by default; override with `DOCKER=docker`.
`prepare.sh` builds in place inside `stblinux/linux`, so the submodule is dirty
afterwards (ignored via `.gitmodules`).

Loading on the box: the stock busybox has no `insmod`/`rmmod`; use a separate userland
(e.g. an Alpine chroot). The module name is the object name, not the filename.

## Why the config looks the way it does

**A CRC match is not layout proof.** modversions CRCs only cover exported function
signatures, so a module can load cleanly and still read the wrong struct offsets
(the first fuse build hit `task->cred` at 0x2a4 instead of 0x2ac → EACCES). The
fragment was derived by diffing the device Image against our vmlinux (symbols,
function sizes, offset-by-offset disassembly). Highlights:

- `DEBUG_SPINLOCK`, `DEBUG_RT_MUTEXES`, `DEBUG_ATOMIC_SLEEP` on (spinlock / preempt_count size)
- stack protector on (`task_struct.stack_canary`)
- LPAE, CGROUPS, DETECT_HUNG_TASK, LED class/triggers, DEBUG_FS, BSG, USB_MON, IPV6_SIT, XFRM off
- NETFILTER / NF_CONNTRACK / NET_SCHED / CLS_ACT / IPV6 on (`sk_buff` layout)
- `KEYS` off — the device has no keyring

What remains after the config are TiVo source changes (struct padding), covered by
`tivo-layout.patch`. The extra TiVo fields are padding only — their semantics aren't known.

**Not covered:** the proprietary modules (`tv_bcmdriver`, `bcmdriver`, …) export
scrambled symbol names, so their inter-module APIs aren't in `Module.symvers.device`.
Everything exported by vmlinux is.
