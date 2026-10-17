# Sourced by prepare.sh / kbuild.sh: pick the toolchain flavour for this host (docker/Dockerfile).
#   x86_64: cross gcc-4.8-arm-linux-gnueabihf 4.8.3  -> tivo-kbuild:4.8.3-amd64
#   armv7l: native gcc-4.8 4.8.3 (Pi booted 32-bit)  -> tivo-kbuild:4.8.3-armhf
case "$(uname -m)" in
  x86_64)        UARCH=amd64; CROSS_COMPILE=arm-linux-gnueabihf- ;;
  armv7l|armv8l) UARCH=armhf; CROSS_COMPILE= ;;
  *) echo "unsupported build host: $(uname -m) (need x86_64 or armv7l)"; exit 1 ;;
esac
IMAGE=${IMAGE:-tivo-kbuild:4.8.3-$UARCH}
if [ -z "$DOCKER" ]; then docker info >/dev/null 2>&1 && DOCKER=docker || DOCKER="sudo docker"; fi
KTREE=stblinux/linux
