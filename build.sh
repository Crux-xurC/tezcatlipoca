#!/usr/bin/env bash
# build.sh -- make the tezcatlipoca tarball from the commits in versions.lock.
#
#   ./build.sh          -> dist/tezcatlipoca-<VERSION>-linux-x86_64.tar.gz (+ .sha256)
#
# For each component it clones (once) into _work/src/<name>, checks out the
# locked commit, and builds what needs building:
#   tezcatl_without_nix, xipe_totec_without_nix  mix release (Erlang's runtime included)
#   poca                                        cmake, in _work/poca-build (CEF from POCA_VENDOR)
#   embody, emacs-vent                          nothing (files)
# then puts each component's committed files (git archive) and its build into
# _work/stage/tezcatlipoca-<VERSION>/, with bundle/ (the tezcatlipoca command,
# its README), and makes the tarball.
#
# Needs: git (with access to the repositories), Elixir and Erlang/OTP, gcc/g++,
# make, libcap, CMake 3.21+, ninja, strip, and the CEF binary distribution
# Poca's README names: POCA_VENDOR is the directory holding it (Poca's
# vendor/; default ../poca/vendor beside this repository). Build outside any
# Nix shell: the releases carry the Erlang runtime they are built with.
#
# The result runs on Linux x86_64 with a glibc at least as new as this
# machine's (written into the tarball's BUILD file).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# where the checkouts and builds go. Its path is written into what is built
# (Elixir's __DIR__, C++'s __FILE__), so for a tarball to publish use one
# without personal names in it, e.g. TEZCATLIPOCA_WORK=/var/tmp/tezcatlipoca
work="${TEZCATLIPOCA_WORK:-$root/_work}"
version="$(tr -d '[:space:]' < "$root/VERSION")"
name="tezcatlipoca-$version-linux-x86_64"
stage="$work/stage/tezcatlipoca-$version"
POCA_VENDOR="${POCA_VENDOR:-$root/../poca/vendor}"

if [ -n "${IN_NIX_SHELL:-}" ]; then
  echo "build.sh: run outside a Nix shell (the releases would carry Nix's Erlang)" >&2
  exit 1
fi
[ -d "$POCA_VENDOR" ] || { echo "build.sh: no CEF at POCA_VENDOR=$POCA_VENDOR (see Poca's README, Build)" >&2; exit 1; }

# --- the locked commits ----------------------------------------------------------
declare -A url commit
order=()
while read -r n u c; do
  case "$n" in ''|'#'*) continue ;; esac
  url[$n]="$u"; commit[$n]="$c"; order+=("$n")
done < "$root/versions.lock"

mkdir -p "$work/src"
for n in "${order[@]}"; do
  src="$work/src/$n"
  if [ ! -d "$src/.git" ]; then
    echo "build.sh: clone $n"
    git clone --quiet "${url[$n]}" "$src"
  fi
  git -C "$src" fetch --quiet origin
  git -C "$src" checkout --quiet --detach "${commit[$n]}"
  # anything not committed, except the builds kept between runs
  git -C "$src" clean -fdxq -e /_build -e /deps
  echo "build.sh: $n at $(git -C "$src" rev-parse --short HEAD)"
done

# --- builds ----------------------------------------------------------------------
for n in tezcatl_without_nix xipe_totec_without_nix; do
  echo "build.sh: release of $n"
  ( cd "$work/src/$n" && bin/release ) > "$work/$n.release.log" 2>&1 \
    || { echo "build.sh: release of $n failed: $work/$n.release.log" >&2; exit 1; }
done

echo "build.sh: Poca (cmake)"
ln -sfn "$(cd "$POCA_VENDOR" && pwd)" "$work/src/poca/vendor"
cmake -S "$work/src/poca" -B "$work/poca-build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  "-DCMAKE_CXX_FLAGS=-ffile-prefix-map=$work/src/poca=poca -ffile-prefix-map=$work/poca-build=poca-build" > "$work/poca.build.log" 2>&1 \
  && cmake --build "$work/poca-build" --target poca -j >> "$work/poca.build.log" 2>&1 \
  || { echo "build.sh: Poca failed: $work/poca.build.log" >&2; exit 1; }
rm -f "$work/src/poca/vendor"

# --- stage -----------------------------------------------------------------------
echo "build.sh: stage $stage"
rm -rf "$stage"
mkdir -p "$stage"
put() { # put <name> <dir in the bundle>: the component's committed files
  mkdir -p "$stage/$2"
  git -C "$work/src/$1" archive "${commit[$1]}" | tar -x -C "$stage/$2"
}
put tezcatl_without_nix tezcatl
put xipe_totec_without_nix xipe_totec
put embody embody
put emacs-vent emacs-vent
for n in tezcatl_without_nix:tezcatl xipe_totec_without_nix:xipe_totec; do
  mkdir -p "$stage/${n#*:}/_build/prod"
  cp -a "$work/src/${n%%:*}/_build/prod/rel" "$stage/${n#*:}/_build/prod/"
done
# Poca: what CEF needs beside the program (build/Release), the debug
# information left out (libcef.so is 1.4 GB with it)
mkdir -p "$stage/poca"
cp -a "$work/poca-build/Release/." "$stage/poca/"
git -C "$work/src/poca" archive "${commit[poca]}" LICENSE README.md | tar -x -C "$stage/poca"
# CEF's license and Chromium's credits (the third-party notices), from the CEF distribution
cef="$(ls -d "$POCA_VENDOR"/cef_binary_* | head -1)"
cp "$cef/LICENSE.txt" "$stage/poca/LICENSE-CEF.txt"
cp "$cef/CREDITS.html" "$stage/poca/CREDITS-Chromium.html"
strip --strip-debug "$stage/poca/libcef.so" "$stage/poca/libvk_swiftshader.so" "$stage/poca/poca"
cp -a "$root/bundle/." "$stage/"
cp "$root/LICENSE" "$stage/LICENSE"

{
  echo "tezcatlipoca $version"
  echo "built $(date -u +%Y-%m-%dT%H:%MZ) on $(uname -sm), $(ldd --version | head -1)"
  echo "Elixir $(elixir --short-version), Erlang/OTP $(erl -noshell -eval 'io:put_chars(erlang:system_info(otp_release)), halt().')"
  echo
  echo "# name  repository  commit"
  for n in "${order[@]}"; do echo "$n  ${url[$n]}  ${commit[$n]}"; done
} > "$stage/BUILD"

# --- no path of this machine's home in what is published -------------------------
if leaks="$(grep -rlaF "$HOME/" "$stage" | head -5)" && [ -n "$leaks" ]; then
  echo "build.sh: these hold $HOME's path (build in a TEZCATLIPOCA_WORK outside it):" >&2
  echo "$leaks" | sed "s|^|  |" >&2
  [ -n "${TEZCATLIPOCA_ALLOW_HOME:-}" ] || exit 1
fi

# --- tarball ---------------------------------------------------------------------
mkdir -p "$root/dist"
tar -C "$work/stage" -czf "$root/dist/$name.tar.gz" "tezcatlipoca-$version"
( cd "$root/dist" && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256" )
echo "build.sh: $(du -h "$root/dist/$name.tar.gz" | cut -f1)  dist/$name.tar.gz"
