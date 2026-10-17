# bolt-kernel

Build environment for **out-of-tree loadable kernel modules** for the TiVo Bolt
(kernel `3.14.28-1.16`, ARMv7 Brahma-B15). Produces `.ko`s that pass the box's
`vermagic` + `modversions` checks *and* match its struct layouts.

```
vermagic = 3.14.28-1.16 SMP mod_unload modversions ARMv7 p2v8
```

## Tested live

Built with this toolchain (gcc 4.8.3, x86_64 cross) and loaded on a Bolt:

| Module(s) | Test | Result |
|---|---|---|
| hello, chrdev_demo | load, run, unload | OK. chrdev registers major 253 |
| fuse | sshfs suite: 8M read and 16M write md5, 300-file metadata, rename/symlink/chmod/truncate, 4 parallel readers, mmap, remount, rmmod | all pass |
| md4 md5 hmac arc4 ecb cmac + cifs | SMB 3.0 mount of a Samba share: 16M read/write md5, 200 small files, rename, parallel readers, umount, rmmod | all pass |
| ff-memless, led_class, xpad, joydev | wired Xbox 360 pad: input events, ring LED, strong/weak rumble, 200-update rumble stress, jstest | all pass |

cifs sometimes logs `CIFS VFS: SMB response too long (65616 bytes)` against a modern Samba. The
earlier gcc 4.9.2 builds do the same, and data is unaffected.

Not load-tested: cuse and the USB-serial drivers (ch341, pl2303, ftdi_sio, cp210x, cdc-acm).
Those module sources are copies of the in-tree drivers, with xpad carrying a backported output
queue, and are not included here.

## Layout

| Path | What |
|---|---|
| `stblinux/` | submodule: Broadcom stblinux-3.14 @ tag `stblinux-3.14-1.16` (kernel under `linux/`) |
| `docker/Dockerfile` | Ubuntu 14.10 toolchain, **gcc 4.8.3**, the device kernel's version. `UARCH=amd64` gives the cross build, `UARCH=armhf` the native one |
| `env.sh` | picks `UARCH`/`CROSS_COMPILE` by `uname -m`; uses `sudo docker` only if plain `docker` doesn't work |
| `config/bolt_fragment.config` | appended to `brcmstb_defconfig` — every line is there to match the device's struct layouts |
| `patches/tivo-layout.patch` | pads `struct request` / `request_queue` / `task_struct` to the TiVo offsets |
| `patches/cifs-no-keys.patch` | drops cifs's `select KEYS` (device kernel has no keyring) |
| `symvers/Module.symvers.device` | the device's full export CRC table (5845 symbols), extracted from the kernel Image |
| `prepare.sh` | one-time: build image, apply patch, configure, `modules_prepare` |
| `kbuild.sh <dir>` | build a module dir against the prepared tree |
| `verify.py <ko>` | vermagic + CRC + undefined-symbol go/no-go against the device table |
| `mod/hello/` | smoke-test module |

## Usage

Works on **x86_64** (cross) or **armv7l** (native, e.g. a Pi 4 booted 32-bit). Needs docker,
`patch`, python3 and ARM binutils for `verify.py` (`apt install binutils-arm-linux-gnueabihf`).

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/lart2150/bolt-kernel.git
cd bolt-kernel
./prepare.sh                     # once (or after re-checking-out stblinux)
./kbuild.sh mod/hello            # -> mod/hello/hello.ko
./verify.py mod/hello/hello.ko   # WILL LOAD ON BOLT: YES
```

`prepare.sh` builds in place inside `stblinux/linux`, so the submodule is dirty
afterwards (ignored via `.gitmodules`). The prepared tree is tied to the host arch and
toolchain image that prepared it, and `prepare.sh` cleans it if either changes.

## Toolchain

The device kernel banner says `gcc version 4.8.3 (GCC)`. Ubuntu 14.10 (utopic) shipped gcc 4.8.3,
both as a native armhf compiler and as an `arm-linux-gnueabihf` cross compiler, and both are still
on old-releases.ubuntu.com. Docker 29 can't pull the `ubuntu:14.10` image (v1 manifest), so the
Dockerfile starts from Ubuntu's 14.10 core rootfs tarball. Its sha256 comes from SHA256SUMS signed
by the Ubuntu CD Image key `C598 6B4F 1257 FFA8 6632 CBA7 4618 1433 FBB7 5451`.

Rebuilding the stock modules TiVo ships (cdc-acm, ftdi_sio, evdev) and comparing `.text` to the
device's own binaries:

| | gcc 4.9.2 (jessie) | Linaro 4.9.4 | **utopic 4.8.3** |
|---|---|---|---|
| cdc-acm | 55.5% | 50.4% | **97.8%** |
| ftdi_sio | 59.7% (+160 B) | 44.3% (+148 B) | **94.6% (same size)** |
| evdev | 37.0% | 36.0% | **65.6%** |

(The percentages are the device's instruction words matched in order.) Struct layouts don't depend
on the compiler; the `offsetof`/`sizeof` probe is byte-identical across all three.

The x86_64 cross build and the armv7l native build produce byte-identical `.text` for every
module, so it doesn't matter which host you build on.

Build speed, Ryzen 9 7900X under WSL vs Pi 4: a full prepare takes 6 s vs 52 s, and a clean
`cifs.ko` 1.9 s vs 25 s. Container startup alone is about 9 s on the Pi.

## Loading

The stock busybox has no `insmod`/`rmmod`; use a separate userland
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
