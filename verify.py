#!/usr/bin/env python3
"""Verify a .ko will load on the TiVo Bolt: vermagic + modversion CRCs + undefined symbols."""
import struct, subprocess, os, sys, tempfile
TARGET = "3.14.28-1.16 SMP mod_unload modversions ARMv7 p2v8"
OC = "arm-linux-gnueabihf-objcopy"; NM = "arm-linux-gnueabihf-nm"
DEVTBL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "symvers", "Module.symvers.device")

def section(ko, sec):
    t = tempfile.mktemp()
    subprocess.run([OC, "-O", "binary", "--only-section="+sec, ko, t], stderr=subprocess.DEVNULL)
    d = open(t, "rb").read() if os.path.exists(t) else b""
    if os.path.exists(t): os.unlink(t)
    return d

ko = sys.argv[1]
mi = section(ko, ".modinfo"); vermagic = ""
for f in mi.split(b"\0"):
    if f.startswith(b"vermagic="): vermagic = f[9:].decode().strip()
vm_ok = vermagic == TARGET

dev = {}
for line in open(DEVTBL):
    p = line.rstrip("\n").split("\t"); dev[p[1]] = int(p[0], 16)

v = section(ko, "__versions"); mod = {}
for i in range(0, len(v), 64):
    crc = struct.unpack("<I", v[i:i+4])[0]
    name = v[i+4:i+64].split(b"\0", 1)[0].decode(errors="replace")
    if name: mod[name] = crc
crc_missing = [n for n in mod if n not in dev]
crc_bad = [n for n in mod if n in dev and dev[n] != mod[n]]

nm = subprocess.run([NM, ko], capture_output=True, text=True).stdout
undU = [p[-1] for p in (l.split() for l in nm.splitlines()) if len(p) >= 2 and p[-2] == "U"]
und_missing = sorted(set(s for s in undU if s not in dev))

print("ko:        ", ko)
print("vermagic:  ", repr(vermagic), "->", "OK" if vm_ok else "MISMATCH")
print("versioned imports:", len(mod), "| crc-missing:", len(crc_missing), "| crc-mismatch:", len(crc_bad))
if crc_missing: print("   crc-missing:", crc_missing[:20])
if crc_bad: print("   crc-mismatch:", crc_bad[:20])
print("undefined syms NOT provided by kernel:", len(und_missing))
if und_missing: print("   ->", und_missing[:30])
loadable = vm_ok and not crc_missing and not crc_bad and not und_missing
print("WILL LOAD ON BOLT:", "YES" if loadable else "NO (fix the above)")
sys.exit(0 if loadable else 1)
