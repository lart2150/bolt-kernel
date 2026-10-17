# Sourced by prepare.sh / kbuild.sh: pick the toolchain image for this host.
#   armv7l (Pi booted 32-bit): native build, docker/Dockerfile      -> tivo-kbuild:3.14
#   x86_64:                    cross build,  docker/Dockerfile.x64  -> tivo-kbuild:3.14-x64
case "$(uname -m)" in
  armv7l|armv8l) DEF_IMAGE=tivo-kbuild:3.14;     DOCKERFILE=docker/Dockerfile ;;
  x86_64)        DEF_IMAGE=tivo-kbuild:3.14-x64; DOCKERFILE=docker/Dockerfile.x64 ;;
  *) echo "unsupported build host: $(uname -m) (need armv7l or x86_64)"; exit 1 ;;
esac
IMAGE=${IMAGE:-$DEF_IMAGE}
if [ -z "$DOCKER" ]; then docker info >/dev/null 2>&1 && DOCKER=docker || DOCKER="sudo docker"; fi
KTREE=stblinux/linux
