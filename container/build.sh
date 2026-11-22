#!/usr/bin/env bash
# container/build.sh -- build the tarball in Ubuntu 22.04 (glibc 2.35, OpenSSL 3.0),
# so it runs on Ubuntu 22.04 / 24.04, Debian 12 and newer, not only on this machine's glibc.
#
#   container/build.sh image     make the image tezcatlipoca-build:22.04 once (Erlang/OTP from source: ~10 min)
#   container/build.sh           ../build.sh inside it -> dist/ (environment variables of build.sh pass through)
#
# Needs podman (rootless) and the CEF distribution under ~/.local/share/cef/. The image is made by
# `podman run` + `podman commit` of container/setup.sh, not by `podman build`, so it also works where
# podman cannot mount an overlay. The build runs as a user `builder` (home /home/builder) mapped to
# you (--userns=keep-id): build.sh's check finds neither your home nor your name in what is built.
# PODMAN="podman --storage-driver vfs --root ~/.local/share/containers/storage-vfs" when the kernel
# offers no overlay; PODMAN_NET="--network host" when it offers no /dev/net/tun (a kernel updated
# without a reboot lacks both).
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
podman=(${PODMAN:-podman})
net=(${PODMAN_NET:-})
image=localhost/tezcatlipoca-build:22.04

if [ "${1:-}" = image ]; then
  "${podman[@]}" rm -f tzb-setup >/dev/null 2>&1 || true
  "${podman[@]}" run "${net[@]}" --name tzb-setup -v "$here/container/setup.sh:/setup.sh:ro" \
    docker.io/library/ubuntu:22.04 /setup.sh
  "${podman[@]}" commit --change 'ENV PATH=/usr/local/elixir/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
    --change 'ENV LANG=C.UTF-8' --change 'ENV LC_ALL=C.UTF-8' tzb-setup "$image"
  "${podman[@]}" rm -f tzb-setup >/dev/null
  # the user the build runs as, with Hex and rebar of its own
  "${podman[@]}" run "${net[@]}" --name tzb-setup "$image" useradd -m -u "$(id -u)" -s /bin/sh builder
  "${podman[@]}" commit --change 'USER builder' --change 'ENV HOME=/home/builder' --change 'WORKDIR /home/builder' tzb-setup "$image"
  "${podman[@]}" rm -f tzb-setup >/dev/null
  "${podman[@]}" run "${net[@]}" --userns=keep-id --name tzb-setup "$image" sh -c 'mix local.hex --force && mix local.rebar --force'
  "${podman[@]}" commit tzb-setup "$image"
  "${podman[@]}" rm -f tzb-setup >/dev/null
  exit 0
fi

work="${TEZCATLIPOCA_CONTAINER_WORK:-$here/_work-22.04}"
mkdir -p "$work"
pass=()
for v in TEZCATLIPOCA_ALLOW_LAG TEZCATLIPOCA_KEEP_BUILDS TEZCATLIPOCA_ALLOW_HOME SOURCE_DATE_EPOCH; do
  [ -n "${!v:-}" ] && pass+=(-e "$v=${!v}")
done
exec "${podman[@]}" run --rm "${net[@]}" --userns=keep-id \
  -v "$here:/src/tezcatlipoca" -v "$work:/var/tmp/tezcatlipoca" \
  -v "$HOME/.local/share/cef:/home/builder/.local/share/cef:ro" \
  -e TEZCATLIPOCA_WORK=/var/tmp/tezcatlipoca "${pass[@]}" \
  -w /src/tezcatlipoca "$image" sh -c 'git config --global --add safe.directory "*"; ./build.sh'
